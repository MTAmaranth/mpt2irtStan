// ----- Boeckenholt extended: Response styles -----
// ----- Unconstrained beta_e* parameters ----------

// 1,...j,...,J: number of items
// 1,...i,...,N: number of participants
// S: number of parameters (extended Boeckenholt: 4: middle/trait/extremity/acquies)
// X: N(person) x J(item) x C(categories) array of observed frequencies
// X: N(person) x J(item) matrix with observed response category

// ----- Hyperpriors
// df: degrees of freedom for scaled inverse wishart (>=S, typically df=S+1)
// V: S x S hyperprior for wishart

// ----------------------------------------
data {
	// data and indices
	int<lower=1> N;  					 // number of persons
	int<lower=1> J;  					 // number of items
	array[N, J] int<lower=1, upper=5> X;	     // chosen responses of partipants
	int<lower=1> S;						 // number of theta-parameters (2012-version: S=3
	array[J] int<lower=0, upper=1> revItem;   // index for reversed items (=1)
	array[J] int<lower=1> traitItem;   		// index for trait items (1,...,n.trait)
	// real<lower=0> T1_CONST;              // constant added to mean-expected frequencies of zero
	int<lower=1> N2;  					 // number of persons for whom to draw posterior predictives
	
	// hyperpriors
	vector[S] theta_mu;  // mean of theta
	int<lower=S+1> df;   // df for wishart, often S+1
	cov_matrix[S] V;     // hyperprior for wishart, e.g., diag(S)
}

// ----------------------------------------
parameters {
  // person parameters: middle, trait, extreme
  array[N] vector[S] theta_raw;                      // unscaled latent trait values
  vector<lower=0, upper=100>[S] xi_theta;      // scaling parameters
  cov_matrix[S] Sigma_raw;                     // unscaled covariance matrix of traits
  
  // item parameters: middle, extreme, acq, trait
  matrix<lower=-5, upper=5>[J, 5] beta_raw;    // raw item difficulties
  // vector<lower=0, upper=100>[S] xi_beta;    // scaling parameters items
  vector<lower=-5, upper=5>[S+1] mu_beta;        // raw item means
  vector<lower=0>[S+2] sigma2_beta_raw;          // raw item variance
  // vector<lower=-5, upper=5>[J] beta_ARS_extreme;    // latent overall level of extremity after ARS
} 

// ----------------------------------------
transformed parameters {
    matrix[N, S] theta;                    // latent traits
    cov_matrix[S] Sigma;                   // covariance matrix of traits
    
    matrix[J, 5] beta;     			       // item difficulties
    vector<lower=0>[S+1] sigma_beta_raw;   // raw item variance
    array[N, J] simplex[5] p_cat;               // response category probabilities
    array[N, J] real<lower=0, upper=1> middle;   // item-person probability to select middle category
    array[N, J] real<lower=0, upper=1> extreme;  // item-person probability to respond extremely
    array[N, J] real<lower=0, upper=1> acquies;  // item-person probability for acquiescence
    array[N, J] real<lower=0, upper=1> trait;  // item-person probability to respond positive/negative
    array[N, J] real<lower=0, upper=1> extreme_a;  // latent overall level of extremity after ARS
    
    // scaling of variance
    Sigma = diag_matrix(xi_theta) * Sigma_raw* diag_matrix(xi_theta);
    
    // print("log-posterior = ", target());
    
    // ----- rescaling of item parameters
    for(s in 1:(S+1)){
    	sigma_beta_raw[s] = sqrt(sigma2_beta_raw[s]);
    }
    for(j in 1:J){
    	// Response styles: MRS and ERS
    	for(s in 1:5) {
    		// independent univariate normal 
    		// beta[j,s] = mu_beta[s] + xi_beta[s] * beta_raw[j,s];
    		if (s == 4) {
    		    // Trait(s):
    	        // beta[j,4] =  mu_beta[3+traitItem[j]]+ xi_beta[3+traitItem[j]] * beta_raw[j,4];
    	        beta[j,4] =  mu_beta[3+traitItem[j]] + beta_raw[j,4];
    		} else {
    		    beta[j,s] = mu_beta[s] + beta_raw[j,s];
    		}
    	}
    }
    
     for(i in 1:N){	
    	// rescale trait values
    	for(s in 1:S){
    		theta[i,s] = theta_raw[i,s] * xi_theta[s];
    	}
    	
    	// loop across items
    	for(j in 1:J){
    		// IRT: 1. additive combination of trait and difficulty
    		//      2. transform to probabilities using Phi (trait: consider reversed items!)
    		middle[i,j] = Phi_approx(theta[i,1]-beta[j,1]);   // Phi_approx()
    		extreme[i,j] =  Phi_approx(theta[i,2]-beta[j,2]);
    		acquies[i,j] =  Phi_approx(theta[i,3]-beta[j,3]);
    		// standard items: theta-beta  // reversed items: beta-theta
    		// if (traitItem[j] > 0) {
    	        trait[i,j] =  Phi_approx( (-1)^revItem[j] *(theta[i,3+traitItem[j]]-beta[j,4]) );
    		// } else {
    		//     trait[i,j] =  Phi_approx( (-1)^revItem[j] *(-beta[j,4]) );
    		// }
    	    extreme_a[i,j] = Phi_approx(theta[i,2] - beta[j, 5]);
    		
    		// response probabilities: MPT model for response categories 1, 2, 3, 4, 5
    		p_cat[i,j,1] = (1-acquies[i,j])*(1-middle[i,j])*(1-trait[i,j])*extreme[i,j];
    		p_cat[i,j,2] = (1-acquies[i,j])*(1-middle[i,j])*(1-trait[i,j])*(1-extreme[i,j]);
    		p_cat[i,j,3] = (1-acquies[i,j])*   middle[i,j];
    		p_cat[i,j,4] = (1-acquies[i,j])*(1-middle[i,j])*trait[i,j]*(1-extreme[i,j]) + acquies[i,j]*(1    -extreme_a[i,j]);
    		p_cat[i,j,5] = (1-acquies[i,j])*(1-middle[i,j])*trait[i,j]*extreme[i,j]     + acquies[i,j]*       extreme_a[i,j];
    	}
    }
}
		

// ----------------------------------------
model {

    // ----- independent univariate normals for item difficulties: 
    for(j in 1:J){
    	// MRS, ERS, ARS:
    	for(s in 1:5){
    	    if (s == 4) {
    	        // Trait(s):
    	        beta_raw[j,4] ~ normal(0, sigma_beta_raw[3+traitItem[j]]);
    	    } else {
    	        beta_raw[j,s] ~ normal(0, sigma_beta_raw[s]);
    	    }
    	}
	}
	
    // ----- hyperpriors:
    // implicit uniform on scaling parameters
    // beta_ARS_extreme ~ normal(0, 1);
    // xi_theta, xi_beta ~ uniform (0, 100);     
    mu_beta ~ normal(0, 1);            // raw item mean
    sigma2_beta_raw ~ inv_gamma(1,1);  // raw item variance
    Sigma_raw ~ inv_wishart(df, V);    // person hyperprior
    
    for(i in 1:N){
    	for(j in 1:J){
    		// distribution of observed frequencies
    		X[i,j] ~ categorical(p_cat[i,j]);      // categorical data dim(X)= N x J
    	}
    	
    	// Hierarchical model for participant parameters
    	// fix person mean to zero for weak identification
    	theta_raw[i] ~ multi_normal(theta_mu, Sigma_raw); 
    }
}

// ----- posterior predictive
generated quantities {
    array[N2, J] int<lower=1, upper=5> X_pred;	  // predicted responses of partipants
    
    // int<lower=1, upper=5> ZX_pred[J];	  // predicted responses of theta=0
    // simplex[5] Zp_cat[J];
    // real<lower=0, upper=1> Zmiddle[J];
    // real<lower=0, upper=1> Zextreme[J];
    // real<lower=0, upper=1> Zacquies[J];
    // real<lower=0, upper=1> Ztrait[J];
    // real<lower=0, upper=1> Zextreme_a;
    
	vector<lower=0>[S+1] sigma_beta;	      // item SD
	
	cov_matrix[S] Corr;

    // matrix[J,5] diff_item_obs;
    // matrix[J,5] diff_item_pred;
    // matrix<lower=0, upper=N>[J,5] mean_item_exp;
    // matrix<lower=0, upper=N>[J,5] freq_item_obs;
    // matrix<lower=0, upper=N>[J,5] freq_item_pred;
    // 
    // matrix[N,5] diff_part_obs;
    // matrix[N,5] diff_part_pred;
    // matrix<lower=0, upper=J>[N,5] mean_part_exp;
    // matrix<lower=0, upper=J>[N,5] freq_part_obs;
    // matrix<lower=0, upper=J>[N,5] freq_part_pred;
    // 
    // 
    // real<lower=0> T1_part_obs;
    // real<lower=0> T1_part_pred;
    // int<lower=0, upper=1> p_T1_part;
    // real<lower=0> T1_item_obs;
    // real<lower=0> T1_item_pred;
    // int<lower=0, upper=1> p_T1_item;

    // rescaled item mean and SD
    // sigma_beta = xi_beta .* sigma_beta_raw;
    sigma_beta = rep_vector(1, (S+1)) .* sigma_beta_raw;
    
    Corr = diag_matrix(inv_sqrt(diagonal(Sigma))) * Sigma * diag_matrix(inv_sqrt(diagonal(Sigma)));

    // for(i in 1:N){
    // 	for(j in 1:J){
    // 	    X_pred[i,j] = categorical_rng(p_cat[i,j]);
    // 	}
    // }
    
    // ----- POSTERIOR PREDICTIVE (either for N or for theta=0)
    
    for(i in 1:N2){
    	for(j in 1:J){
    	    X_pred[i,j] = categorical_rng(p_cat[i,j]);
    	}
    }
}
