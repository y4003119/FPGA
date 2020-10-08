`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 2020/10/08 20:33:12
// Design Name: 
// Module Name: i2c_phy
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module i2c_phy#(
parameter       IIC_F100K = 10'd500,            //100K-500
parameter       IIC_F400K = 10'd125            //100K-500
)(

input                   clk_50m,
input                   rst_n,

input           [1:0]   cmd,
//input           [7:0]   wr_data,
input           [15:0]  addr_and_data,
input           [6:0]   device_addr,

output     reg          done,
output     reg  [7:0]   rd_data,

inout                   SDA,
inout                   SCL                     //100K
);
    
//===================================================
localparam      IIC_F4_1 = IIC_F100K / 4 -1;                        //100K -125-1   
localparam      IIC_F4_2 = (IIC_F100K / 4) *2 -1;                   //100K -250-1   
localparam      IIC_F4_3 = (IIC_F100K / 4) *3 -1;                   //100K -375-1   
localparam      IIC_F4_4 = IIC_F100K -1;                            //100K -500-1   

localparam      DELAY = 1000;           //20us
//===================================================
reg         [8:0]   st;
reg         [8:0]   back_st;

reg         [15:0]  delay_cnt;
reg         [9:0]   count; 
reg                 ack;
reg         [7:0]   send_data;
reg         [8:0]   send_data_1; 
reg         [7:0]   n;  

reg                 sel_sda, reg_sda;
reg                 sel_scl, reg_scl;

assign  SDA = sel_sda ? reg_sda : 1'bz;
assign  SCL = sel_scl ? reg_scl : 1'bz;

//========================================================

always @ (posedge clk_50m)
if(!rst_n)
begin
    st <= 0;
    back_st <= 0;
    
    delay_cnt <= 0;
    count <= 0;
    
    ack <= 0;
    sel_sda <= 0;
    sel_scl <= 0;
    reg_sda <= 0;
    reg_scl <= 0;
    
    done <= 0;
    rd_data <= 0;
    send_data <= 0;
    send_data_1 <= 0;
end
else if(cmd == 2'b01)                   //wr
begin
//============================================================
//IIC_WRITE
case(st)
0:
begin
    st <= 1;  
    back_st <= 0;
    delay_cnt <= 0;
    count <= 0;
    ack <= 1;
    sel_sda <= 1;
    sel_scl <= 1;
    reg_sda <= 1;
    reg_scl <= 1;
    done <= 0;
    rd_data <= 0;
    send_data <= 0;
    send_data_1 <= 0;
    n <= 8'd9;
end
//=================START
1:
begin
    sel_sda <= 1;
    sel_scl <= 1;
    if(count == 0) 
        reg_scl <= 1'b1;
    else if(count == IIC_F4_2)
        reg_scl <= 1'b0;
    
    if(count == 0)
        reg_sda <= 0;
    
    if(count == IIC_F4_3 - 1)
    begin
        count <= 0;
        st <= 2;
    end
    else
        count <= count +1;
end

//=================WRITE DEVICE
2:
begin
    send_data <= {device_addr, 1'b0};                        //device addr
    st <= 22;
    back_st <= 3;
end
//================WRITE REG ADDR
3: 
begin
    send_data <= {addr_and_data[15:9],1'b0};                        //device addr
    st <= 22;
    back_st <= 4;
end
//===============WRITE DATA
4:
begin
    send_data_1 <= addr_and_data[8:0];                        //device addr
    st <= 33;
    back_st <= 5;
end
//=============================================
//STOP
5:
begin
    sel_sda <= 1'b1;
    
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1)
        reg_scl <= 1'b1;  
    
    if(count == 0)
        reg_sda <= 1'b0;
    else if(count == IIC_F4_2)
        reg_sda <= 1'b1;
        
     if(count == IIC_F4_4 - 1)
     begin
        sel_scl <= 1'b1;
        sel_sda <= 1'b1;
        count <= 0;
        st <= 6;
     end
     else
        count <= count +1;
end
//==================================
//DELAY
6:
begin
    
    if(delay_cnt == DELAY -1)               //20us
    begin
        delay_cnt <= 0;
        done <= 1;
        st <= 7;
    end
    else
        delay_cnt <= delay_cnt +1;
end

7:
begin
    done <= 0;
    st <= 0;
end
//=======================================WRITE CYCLE[7]-[0]
22, 23, 24, 25, 26, 27, 28, 29:
begin
    sel_sda <= 1;
    reg_sda <= send_data[29 - st];
    
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1 )
        reg_scl <= 1'b1;
    else if(count == IIC_F4_3)
        reg_scl <= 1'b0;
        
    if(count == IIC_F4_4)
    begin
        count <= 0;
        st <= st +1;
    end
    else
        count <= count +1;
end
//========================================WRITE [8:0]
33:
begin
    sel_sda <= 1;
    reg_sda <= send_data_1[n-1];
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1 )
        reg_scl <= 1'b1;
    else if(count == IIC_F4_3)
        reg_scl <= 1'b0;
        
    if(count == IIC_F4_4)
    begin
        count <= 0;
    end

    if(n == 1)begin
        st <= 30;
    end
    else
        count <= count +1;
        n <= n-1;
        st <= st;
end
//==============================ACK
30:
begin
    sel_sda <= 1'b0;
    reg_sda <= 1'b1;
    
    if(count == IIC_F4_2 +1)
        ack <= SDA;
        
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1)
        reg_scl <= 1'b1;
    else if(count == IIC_F4_3)
        reg_scl <= 1'b0;

    if(count == IIC_F4_4 - 2)
    begin
        count <= 0;
        st <= 31;
    end
    else
        count <= count +1;
end

31:
begin
    if(!ack)begin
        st <= back_st;
        // done <= 1;
    end
    else
        st <= 0;                        ///error
end
default: st <= 0;
endcase
end 
//============================================================
//IIC_READ
else if(cmd == 2'b10)                   //rd
begin
case(st)
0:
begin
    st <= 1;  
    back_st <= 0;
    delay_cnt <= 0;
    count <= 0;
    ack <= 1;
    sel_sda <= 1;
    sel_scl <= 1;
    reg_sda <= 1;
    reg_scl <= 1;
    done <= 0;
    rd_data <= 0;
    send_data <= 0;
end

//=========================================
//START
1:
begin
    sel_sda <= 1;
    sel_scl <= 1;
    if(count == 0) 
        reg_scl <= 1'b1;
    else if(count == IIC_F4_2)
        reg_scl <= 1'b0;
    
    if(count == 0)
        reg_sda <= 0;
    
    if(count == IIC_F4_3 - 1)
    begin
        count <= 0;
        st <= 2;
    end
    else
        count <= count +1;
end

//=================WRITE DEVICE
2:
begin
    send_data <= {device_addr, 1'b0};                        //device addr
    st <= 22;
    back_st <= 3;
end
//================WRITE REG ADDR
3: 
begin
    send_data <= addr_and_data[15:9];                        //device addr
    st <= 22;
    back_st <= 4;
end

//================
//RESTART
4:
begin
    sel_sda <= 1'b1;
    sel_scl <= 1'b1;
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1 )
        reg_scl <= 1'b1;
    else if(count == IIC_F4_3 )
        reg_scl <= 1'b0;
        
    if(count == 0)
        reg_sda <= 1'b1;
    else if(count == IIC_F4_2 )
        reg_sda <= 1'b0;
    
    if(count == IIC_F4_4 -1)
    begin
        count <= 0;
        st <= 5;
    end
    else
        count <= count +1;
end

//================WRITE DEVICE ADDR
5: 
begin
    send_data <= {device_addr, 1'b1};                        //device addr
    st <= 22;
    back_st <= 6;
end
//=======================================
//READ
6:
begin
    send_data <= 0;
    st <= 13;
    back_st <= 7;
end

//=============================================
//STOP
7:
begin
    sel_sda <= 1'b1;
    
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1)
        reg_scl <= 1'b1;  
    
    if(count == 0)
        reg_sda <= 1'b0;
    else if(count == IIC_F4_2)
        reg_sda <= 1'b1;
        
     if(count == IIC_F4_4 - 1)
     begin
        sel_scl <= 1'b1;
        sel_sda <= 1'b1;
        count <= 0;
        st <= 8;
     end
     else
        count <= count +1;
end
//==================================
//DELAY
8:
begin
    if(delay_cnt == DELAY -1)               //20us
    begin
        delay_cnt <= 0;
        done <= 1;
        st <= 9;
    end
    else
        delay_cnt <= delay_cnt +1;
end

9:
begin
    done <= 0;
    st <= 0;
end

//=======================================WRITE CYCLE[7]-[0]
22, 23, 24, 25, 26, 27, 28, 29:
begin
    sel_sda <= 1;
    reg_sda <= send_data[29 - st];
    
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1 )
        reg_scl <= 1'b1;
    else if(count == IIC_F4_3)
        reg_scl <= 1'b0;
        
    if(count == IIC_F4_4)
    begin
        count <= 0;
        st <= st +1;
    end
    else
        count <= count +1;
end
//==============================ACK
30:
begin
    sel_sda <= 1'b0;
    reg_sda <= 1'b1;
    
    if(count == IIC_F4_2 +1)
        ack <= SDA;
        
    if(count == 0)
        reg_scl <= 1'b0;
    else if(count == IIC_F4_1)
        reg_scl <= 1'b1;
    else if(count == IIC_F4_3)
        reg_scl <= 1'b0;

    if(count == IIC_F4_4 - 2)
    begin
        count <= 0;
        st <= 31;
    end
    else
        count <= count +1;
end

31:
begin
    if(!ack)
        st <= back_st;
    else
        st <= 0;                        ///error
end
//===========================================================READ CYCLE[7]-[0]
13, 14, 15, 16, 17, 18, 19, 20:
begin
    sel_sda <= 1'b0; 
    if(count == IIC_F4_2)
        rd_data[20-st] <= SDA;
    
    if(count == 0)
        reg_scl <= 1'b0;
    else if( count == IIC_F4_1)
        reg_scl <= 1'b1;
    else if( count == IIC_F4_3)
        reg_scl <= 1'b0;
        
    if(count == IIC_F4_4)
    begin
        count <= 0;
        st<= st +1;
    end
    else
        count <= count +1;
end

//=================================
//NO ACK
21:
begin
    sel_sda <= 1'b1;
    reg_sda <= 1'b1;
    
    if(count == 0)
        reg_scl <= 1'b0;
    else if( count == IIC_F4_1)
        reg_scl <= 1'b1;
    else if( count == IIC_F4_3)
        reg_scl <= 1'b0;
    
    if(count == IIC_F4_4)
        begin
            count <= 0;
            st<= back_st;
        end
        else
            count <= count +1;
end

default:    st <= 0;
endcase
end
//============================================================
//else
else
begin
    st <= 0;
    back_st <= 0;
    
    delay_cnt <= 0;
    count <= 0;
    
    ack <= 1;
    sel_sda <= 0;
    sel_scl <= 0;
    reg_sda <= 1;
    reg_scl <= 1;
    
    done <= 0;
    rd_data <= 0;
    send_data <= 0;
end
endmodule
