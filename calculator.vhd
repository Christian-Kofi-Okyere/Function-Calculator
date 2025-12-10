-- Christian Okyere
-- Quartus II VHDL Template
-- Four-State Moore State Machine


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity calculator is

  port( clock: in std_logic; -- clock signal
        b0:    in std_logic; -- button 0, Capture input
        b1:    in std_logic; -- button 1, Enter
        b2:    in std_logic; -- button 2, Action
		  op: 	in std_logic_vector(1 downto 0); -- Action switches(2)
        data:  in std_logic_vector(7 downto 0); -- Input data switches
        digit0: out std_logic_vector(6 downto 0); -- Output values for 7-segment display
        digit1: out std_logic_vector(6 downto 0) -- Output values for 7-segment display
		  
        );


end entity;

architecture rtl of calculator is

	component memram -- component for RAM
		PORT(
			address	: IN STD_LOGIC_VECTOR (3 DOWNTO 0);
			clock		: IN STD_LOGIC  := '1';
			data		: IN STD_LOGIC_VECTOR (7 DOWNTO 0);
			wren		: IN STD_LOGIC ;
			q			: OUT STD_LOGIC_VECTOR (7 DOWNTO 0)
			);
	end component;
	
	component hexdisplay  -- component for display
		port(
			  a	   : in std_logic_vector (3 downto 0);
			  result : out std_logic_vector (6 downto 0)
			);
	end component;

	-- Definitions of the internal signals and registers
	signal RAM_input  	: std_LOGIC_VECTOR(7 downto 0);	-- signal for the RAM input
	signal RAM_output		: std_LOGIC_VECTOR(7 downto 0);	-- signal for the RAM output
	signal RAM_we			: std_LOGIC;	-- signal for RAM write enable
	signal stack_ptr		: unsigned(3 downto 0);	-- signal for stack pointer
	signal mbr 				: std_LOGIC_VECTOR (7 downto 0);	-- signal for memory buffer register
	signal state 			: std_LOGIC_VECTOR (2 downto 0);	-- signal for the states 
	signal holder   		: std_logic_vector (15 downto 0); -- signal for intermediate register storage
	signal counter			: std_logic_vector (7 downto 0); -- signal for the counter
	
begin

	-- port mapping the RAM
	memram1 : memram port map(address => std_LOGIC_VECTOR(stack_ptr), clock => clock, data => RAM_input,
				wren => RAM_we, q => RAM_output);
				
	-- port mapping for the hexdisplay
	hexdisplay1: hexdisplay port map(a => mbr(3 downto 0), result => digit0);
	hexdisplay2: hexdisplay port map(a => mbr(7 downto 4), result => digit1);
	
	-- Logic to advance to the next state
	process (clock, b0, b1)
	begin
		
		-- b0 and b1 are used for resetting the circuit
		if (b0 = '0' and b1 = '0') then
			stack_ptr <= (others => '0');
			mbr <= (others =>'0');
			RAM_input <= (others => '0');
			RAM_we <= '0';
			state <= (others => '0');
			
		elsif (rising_edge(clock)) then
			case state is
				when "000" =>
					if (b0 = '0') then
						mbr <= data;
						
						state <= "111";
						
					elsif (b1 = '0') then
						RAM_input <= mbr;
						RAM_we <= '1';
						state <= "001";
						
					elsif (b2 = '0') then
						if(stack_ptr /= 0) then
							stack_ptr <= stack_ptr - 1;
							counter <= mbr;
							state <= "100";
						end if;					
					end if;
					
				when "001" =>
					RAM_we <= '0';
					stack_ptr <= stack_ptr + 1;
					state <= "111";
					
				when "010" =>  -- exponential operation
					if (counter /= "00000000") then
						holder <= std_logic_vector(unsigned(holder(7 downto 0)) * unsigned(RAM_output(7 downto 0)));
						counter <= std_logic_vector(unsigned(counter) - 1);
						state <= "010";
					else
						state <= "011";
					end if;
					
				when "011" =>
					mbr <= std_logic_vector(holder(7 downto 0));
					state <= "111";
					
				when "100" =>
					state <= "101";
					
				when "101" =>
					state <= "110";
					
				when "110" => 
					case op is
 							mbr <= std_logic_vector(unsigned(RAM_output) + unsigned(mbr));
						when "01"=>
							mbr <= std_logic_vector(unsigned(RAM_output) - unsigned(mbr));
						when "10"=>
							mbr <= std_logic_vector(unsigned(RAM_output(3 downto 0)) * unsigned(mbr(3 downto 0)));
						when others=>							
							mbr <= std_logic_vector(unsigned(RAM_output) + unsigned(mbr));
							
							if (counter = "00000000") then
								mbr <= "00000001"; 
								state <= "111";
							elsif (RAM_output(7 downto 0) = "00000000") then 
								mbr <= "00000000";
								state <= "111";
							else
								holder <= std_logic_vector("00000000" & unsigned(RAM_output(7 downto 0)));
								counter <= std_logic_vector(unsigned(counter) - 1);
								state <= "010";
							end if;										
					end case;								
					
				when "111" => 
					if (b0 = '1' and b1 = '1' and b2 = '1') then
						state <= "000";
					end if;
					
				when others =>
					state <= "000";
					
			end case;
		end if;
	end process;

end rtl;