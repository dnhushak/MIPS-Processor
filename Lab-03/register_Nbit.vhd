library IEEE;
use IEEE.std_logic_1164.all;


entity register_Nbit is
  generic(N : integer := 2);
  port(i_CLK        : in std_logic;     -- Clock input
       i_RST        : in std_logic;     -- Reset input
       i_WE         : in std_logic;     -- Write enable input
       i_D          : in std_logic_vector(N-1 downto 0);     -- Data value input
       o_Q          : out std_logic_vector(N-1 downto 0));   -- Data value output

end register_Nbit;

architecture structure of register_Nbit is
  
  component dff
    port(i_CLK      : in std_logic;     -- Clock input
       i_RST        : in std_logic;     -- Reset input
       i_WE         : in std_logic;     -- Write enable input
       i_D          : in std_logic;     -- Data value input
       o_Q          : out std_logic);   -- Data value output
  end component;
  
begin

	gen_flipflops: for I in 0 to N-1 generate
	      	g_nbitreg : dff 
	      	port map(i_CLK => i_CLK,
		       i_RST => i_RST,
		       i_WE => i_WE,
		       i_D => i_D(I),
		       o_Q => o_Q(I));

    	end generate gen_flipflops;
    
  
end structure;