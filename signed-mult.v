module mult (
	input   signed [24:0] A,
	input   signed [24:0] B,
	output  signed [49:0] prod
);

//    assign prod [49:10] = 15'b0000000000000000;

    array_multiplier #(
    .WIDTH(25)
) mult_inst (
    .a(A),
    .x(B),
    .product(prod)
);


endmodule

module array_multiplier #(
    parameter WIDTH = 25
)(
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] x,
    output [2*WIDTH-1:0] product
);

    // it's x [sth] a [sth]  
    wire [WIDTH-1:0] pre_pp[WIDTH-1:0];
    wire [WIDTH-1:0] pp[WIDTH-1:0];
    // They are [y][x] down is y, right is x for each FA[x][y]
    wire [WIDTH-2:0] sum[WIDTH-1: 0];
    wire [WIDTH-2: 0] carry[WIDTH-1:0];
    
    wire last_product;
    
    
    genvar i, j;
    generate
        // Partial products
        for(i = 0; i < WIDTH - 1; i = i + 1) begin: pp_gen
            assign pre_pp[i] = x[i] ? a : 0;
            // Negate first pp
            assign pp[i][WIDTH-2:0] = pre_pp[i];
            assign pp[i][WIDTH-1] = !pre_pp[i][WIDTH-1];
//            assign pp[i] = x[i] ? a : 0;            
        end
        // For last part we want to flip the whole row to get proper Baugh-Wooley
        assign pre_pp[WIDTH-1] = x[WIDTH-1] ? a : 0;
            // Negate first pp
        assign pp[WIDTH-1][WIDTH-2:0] = ~pre_pp[WIDTH-1];
        assign pp[WIDTH-1][WIDTH-1] = pre_pp[WIDTH-1][WIDTH-1];
        // First row, here 0 at top
        assign product[0] = pp[0][0];
        for(i = 1; i < WIDTH; i = i + 1) begin: first_row
            full_adder fa(
                .above(0),
                .diagonal(pp[0][WIDTH-i]), // it's x0a[WIDTH-1] also makes us skip x0a0
                .cin(pp[1][WIDTH-i-1]), // in case of WIDTH = 5, we go from x1a3
                .sum(sum[0][i-1]),
                .cout(carry[0][i-1])
            );
        end
        // Intermediate rows before last
        for(i = 1; i < WIDTH-1; i =i+1) begin: middle_row_total
            // First we parse the one on the edge, cause it has a different b input
            full_adder fa(
                .above(carry[i-1][0]), // Carry from previous row
                .diagonal(pp[i][WIDTH-1]), // Missing pp from above, x[][4] 
                .cin(pp[i+1][WIDTH-2]), // x i+1, a max -1, cause max will go row lower
                .sum(sum[i][0]), // First sum and carries in array
                .cout(carry[i][0]) 
            );
            // Rest of the row
            for(j = 1; j < WIDTH-1; j = j + 1) begin: middle_row_single
                // j is x, i is y
                full_adder fa(
                    .above(carry[i-1][j]), // Carry from previous row
                    .diagonal(sum[i-1][j-1]), // Sum of previous row, previous col boi 
                    .cin(pp[i+1][WIDTH -j-2]), // Rest of x i+1, from a max - 2
                    .sum(sum[i][j]), // Rest of sum and carries
                    .cout(carry[i][j])
                );
            end
        end
        // Final row
        // First FA has to be weird
        full_adder og_first_last_row (
            .above(carry[WIDTH-2][0]), // Carry from previous row
            .diagonal(pp[WIDTH-1][WIDTH-1]), // Final pp 
            .cin(carry[WIDTH-1][1]), // carry comes from FA in next col 
            .sum(product[2*WIDTH-2]), // This one before final output
            .cout(last_product) // But carry becomes final output
        );
        full_adder extra_fa_final_product(
            .above(1), // Baugh-Wooley
            .diagonal(0), // Doesn't matter
            .cin(last_product), 
            .sum(product[2*WIDTH-1]), // Final product
            .cout() // We can leave this one empty
        );
        // Rest of final row with exception of last one
        for(i = 1; i < WIDTH-2; i = i + 1) begin: last_row
            // Here we go backwards
            full_adder fa(
                .above(carry[WIDTH-2][i]), // Carry from above so WIDTH-1
                .diagonal(sum[WIDTH-2][i-1]), // Sum of previous row, previous col  
                .cin(carry[WIDTH-1][i+1]), // Carry from next FA in last row
                .sum(product[2*WIDTH-2-i]), // Becomes products
                .cout(carry[WIDTH-1][i]) // Our carry becomes ours
            );
        end 
        wire connect_bw;
        wire bw_output;
        // Last of final row, so opposite corner of top left
        full_adder baugh_wooley(
            .above(sum[WIDTH-2][WIDTH-2]), // Those 2 ones compensate for baugh wooley
            .diagonal(1), // They replace the single 1 in next pos
            .cin(1), 
            .sum(bw_output),
            .cout(connect_bw) // Carries to next one
        );
        full_adder fa_last(
                .above(carry[WIDTH-2][WIDTH-2]), // Carry from above so WIDTH-1
                .diagonal(sum[WIDTH-2][WIDTH-3]), // Sum of previous row, previous col  
                .cin(connect_bw), // is zero on corner
                .sum(product[WIDTH]), // Becomes product in the middle
                .cout(carry[WIDTH-1][WIDTH-2]) // Final carry
            );
        // Make sure sums of last column are linked to products
        for(i = 0; i < WIDTH - 2; i = i + 1) begin: last_prods
            assign product[i+1] = sum[i][WIDTH-2];
        end
        assign product[WIDTH-1] = bw_output;
    endgenerate
endmodule


module full_adder(
    input above,
    input diagonal,
    input cin,
    output sum,
    output cout
);
    // I trust vivado on this one
    assign {cout, sum} = above + diagonal + cin;
endmodule
