fscanf              (stdin, "String", nuc_fit_file);
fscanf              (stdin, "String", grid_file);
fscanf              (stdin, "String", weights_file);
fscanf              (stdin, "String", results_file);

ExecuteAFile        (PATH_TO_CURRENT_BF + "FUBAR_tools_iterative.ibf");
LoadFunctionLibrary ("GrabBag");
LoadFunctionLibrary ("WriteDelimitedFiles");

for(residue = 0 ; residue < 20 ; residue += 1)
{
	grid_file = LAST_FILE_PATH +"."+AAString[residue]+".grid_info";
	weights_file = LAST_FILE_PATH +"."+AAString[residue]+".theta";
	fscanf (grid_file, REWIND, "NMatrix,Raw", grid, site_probs);
	fscanf (weights_file, REWIND, "NMatrix", learntWeights);

	site_probs = Eval (site_probs);

	points           = Rows(site_probs["conditionals"]);
	sites  		 = Columns (site_probs["conditionals"]);

	if(Columns(full_table) == 0)
	{
		full_table = {sites, (5*20)};
	}

	transWeights = Transpose(learntWeights);

	P_selection_stamp = {points,1} ["grid[_MATRIX_ELEMENT_ROW_][1]>1"];
	//P_selection_stamp = {points,1} ["grid[_MATRIX_ELEMENT_ROW_][0]<grid[_MATRIX_ELEMENT_ROW_][1]"];
	P_prior = +(learntWeights$P_selection_stamp);

	//pointsWithNoBias = {points,1} ["grid[_MATRIX_ELEMENT_ROW_][1]==1"];
	//pointsWithNoBias = {points,1} ["grid[_MATRIX_ELEMENT_ROW_][1]>1"];

	//positive_selection_stencil = {points,sites} ["grid[_MATRIX_ELEMENT_ROW_][0]<grid[_MATRIX_ELEMENT_ROW_][1]"];
	//negative_selection_stencil = {points,sites} ["grid[_MATRIX_ELEMENT_ROW_][0]>grid[_MATRIX_ELEMENT_ROW_][1]"];
	positive_selection_stencil = {points,sites} ["grid[_MATRIX_ELEMENT_ROW_][1]>1"];
	negative_selection_stencil = {points,sites} ["grid[_MATRIX_ELEMENT_ROW_][1]==1"];

	diag_alpha = {points,points}["grid[_MATRIX_ELEMENT_ROW_][0]*(_MATRIX_ELEMENT_ROW_==_MATRIX_ELEMENT_COLUMN_)"];
	diag_beta  = {points,points}["grid[_MATRIX_ELEMENT_ROW_][1]*(_MATRIX_ELEMENT_ROW_==_MATRIX_ELEMENT_COLUMN_)"];
	    
	condLiks = site_probs["conditionals"];
	norm_matrix         = (transWeights*site_probs["conditionals"]);
	poster_matrix = {points,sites}["(transWeights[_MATRIX_ELEMENT_ROW_]*condLiks[_MATRIX_ELEMENT_ROW_][_MATRIX_ELEMENT_COLUMN_])/norm_matrix[_MATRIX_ELEMENT_COLUMN_]"];
	pos_sel_matrix      = (transWeights*(site_probs["conditionals"]$positive_selection_stencil) / norm_matrix);
	//pos_sel_samples[0] / (1-pos_sel_samples[0]) / (1-priorNN) * priorNN
	pos_sel_bfs= pos_sel_matrix["pos_sel_matrix[_MATRIX_ELEMENT_COLUMN_]/(1-pos_sel_matrix[_MATRIX_ELEMENT_COLUMN_])/ P_prior * (1-P_prior)"];
	neg_sel_matrix      = (transWeights*(site_probs["conditionals"]$negative_selection_stencil) / norm_matrix);
	alpha_matrix        = ((transWeights*diag_alpha*site_probs["conditionals"])/norm_matrix);
	beta_matrix         = ((transWeights*diag_beta*site_probs["conditionals"])/norm_matrix);
	

	/*
	savesite = 100;
	posteriors_at_site = {points,1};
	for(_a = 0 ; _a < points ; _a += 1)
	{
		posteriors_at_site[_a] = poster_matrix[_a][savesite];
		//fprintf(stdout,"diag_beta ",posteriors_at_site[_a], "\n");
	}*/

	bySitePosSel = {sites,5};
	for (s = 0; s < sites; s+=1) {
	    	SetParameter (STATUS_BAR_STATUS_STRING, "Tabulating results for site "+ s + "/" + sites + " " + _formatTimeString(Time(1)-t0),0);
	    	bySitePosSel [s][0] = alpha_matrix[s]; 
	    	bySitePosSel [s][1] = beta_matrix[s];
	    	bySitePosSel [s][2] = neg_sel_matrix[s];
	    	bySitePosSel [s][3] = pos_sel_matrix[s];
	    	bySitePosSel [s][4] = pos_sel_bfs[s];		

		full_table[s][residue*5+0] = alpha_matrix[s];
		full_table[s][residue*5+1] = beta_matrix[s];
		full_table[s][residue*5+2] = neg_sel_matrix[s];
		full_table[s][residue*5+3] = pos_sel_matrix[s];
		full_table[s][residue*5+4] = pos_sel_bfs[s];
	    }
}

 
fubarRowCount     = Rows (bySitePosSel);
site_counter = {};
for (currentFubarIndex = 0; currentFubarIndex < fubarRowCount; currentFubarIndex += 1) {
    site_counter + (currentFubarIndex+1);
}

header = {1, (5*20)+1};
header[0] = "Position";
for(residue = 0 ; residue < 20 ; residue += 1)
{
	header[residue*5+1] = AAString[residue]+":"+"alpha";
	header[residue*5+2] = AAString[residue]+":"+"bias";
	header[residue*5+3] = AAString[residue]+":"+"Prob[bias=1]";
	header[residue*5+4] = AAString[residue]+":"+"Prob[bias>1]";
	header[residue*5+5] = AAString[residue]+":"+"BF[beta>alpha]";
}


WriteSeparatedTable (results_file, header, full_table, site_counter, ",");

