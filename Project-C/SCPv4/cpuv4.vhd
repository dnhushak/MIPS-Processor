library IEEE;
use IEEE.std_logic_1164.all;
use work.mips32.all;
use work.cpurecords.all;

entity cpuv4 is
	-- Use N to change the global bit width of the CPU, A should change with it such that 2^A = N
	-- 64 bit MIPS processor? I think I should get some extra points =D
	generic(DATAWIDTH : integer := 32;
		    A         : integer := 5);
	port(imem_addr  : out m32_vector(DATAWIDTH - 1 downto 0); -- Instruction memory address
		 inst       : in  m32_vector(DATAWIDTH - 1 downto 0); -- Instruction
		 dmem_addr  : out m32_vector(DATAWIDTH - 1 downto 0); -- Data memory address
		 dmem_read  : out m32_1bit;     -- Data memory read?
		 dmem_write : out m32_1bit;     -- Data memory write?
		 dmem_wmask : out m32_4bits;    -- Data memory write mask
		 dmem_rdata : in  m32_vector(DATAWIDTH - 1 downto 0); -- Data memory read data
		 dmem_wdata : out m32_vector(DATAWIDTH - 1 downto 0); -- Data memory write data
		 reset      : in  m32_1bit;     -- Reset signal
		 clock      : in  m32_1bit);    -- System clock
end cpuv4;

architecture structure of cpuv4 is
	component registerfile_Nbit_Mreg is
		-- N is size of register, M is number of registers (MUST be power of 2), A is size of register addresses (A MUST equal log2(M))
		generic(N : integer := DATAWIDTH;
			    M : integer := 32;
			    A : integer := 5);
		port(c_CLK : in  m32_1bit;      -- Clock input
			 i_A   : in  m32_vector(N - 1 downto 0); -- Data Input
			 i_Wa  : in  m32_vector(A - 1 downto 0); -- Write address
			 c_WE  : in  m32_1bit;      -- Global Write Enable
			 c_RST : in  m32_vector(M - 1 downto 0); -- Register Reset vector
			 i_R1a : in  m32_vector(A - 1 downto 0); -- Read 1 address
			 o_D1o : out m32_vector(N - 1 downto 0); -- Read 1 Data Output
			 i_R2a : in  m32_vector(A - 1 downto 0); -- Read 2 address
			 o_D2o : out m32_vector(N - 1 downto 0)); -- Read 2 Data Output
	end component;

	component controlv4 is
		port(op_code       : in  m32_6bits;
			 o_control_out : out m32_control_out);
	end component;

	component fulladder_Nbit is
		generic(N : integer := DATAWIDTH);
		port(i_A : in  m32_vector(N - 1 downto 0);
			 i_B : in  m32_vector(N - 1 downto 0);
			 i_C : in  m32_1bit;
			 o_D : out m32_vector(N - 1 downto 0);
			 o_C : out m32_1bit);
	end component;

	component ALU_Nbit is
		generic(N : integer := DATAWIDTH);
		port(i_A     : in  m32_vector(N - 1 downto 0); --Input A
			 i_B     : in  m32_vector(N - 1 downto 0); --Input B
			 i_Ainv  : in  m32_1bit;    --Invert A
			 i_Binv  : in  m32_1bit;    --Invert B
			 i_C     : in  m32_1bit;    --Carry In
			 c_Op    : in  m32_vector(2 downto 0); --Operation
			 c_Shift : in  m32_2bits;   -- Shift selection
			 o_D     : out m32_vector(N - 1 downto 0); --Output Result
			 o_OF    : out m32_1bit;    --Overflow Output
			 o_Zero  : out m32_1bit);   --Zero Output
	end component;

	component register_Nbit is
		generic(N : integer := DATAWIDTH); -- Size of the register
		port(c_CLK : in  m32_1bit;      -- Clock
			 c_RST : in  m32_1bit;      -- Reset
			 c_WE  : in  m32_1bit;      -- Write enable
			 i_A   : in  m32_vector(N - 1 downto 0); -- Input
			 o_D   : out m32_vector(N - 1 downto 0)); -- Output
	end component;

	component alucontrolv4 is
		port(i_op      : in  m32_3bits; -- ALUv2op out of control
			 i_funct   : in  m32_6bits; -- Bits 0-5 of the instruction word
			 o_alucont : out m32_alucontrol_out); -- Output that determines ALUv2 operation
	end component;

	component mux_Nbit_2in is
		generic(N : integer := 1);      -- Number of bits in the inputs and output
		port(c_S : in  m32_1bit;
			 i_A : in  m32_vector(N - 1 downto 0);
			 i_B : in  m32_vector(N - 1 downto 0);
			 o_D : out m32_vector(N - 1 downto 0));
	end component;

	component extender_Nbit_Mbit is
		generic(N : integer := 8;
			    M : integer := DATAWIDTH);
		port(c_Ext : in  m32_1bit;      --Control Input (0 is zero extension, 1 is sign extension)
			 i_A   : in  m32_vector(N - 1 downto 0); --N-bit Input
			 o_D   : out m32_vector(M - 1 downto 0)); --Full Word Output
	end component;

	component leftshifter_Nbit is
		generic(N : integer := DATAWIDTH;
			    A : integer := A);
		port(i_A     : in  m32_vector(N - 1 downto 0); -- input to shift
			 c_Shamt : in  m32_vector(A - 1 downto 0); -- amount to shift by
			 o_D     : out m32_vector(N - 1 downto 0)); -- shifted output
	end component;

	component instruction_decoder
		port(i_instr_bit : in  m32_word;
			 c_clk       : in  m32_1bit;
			 o_instr_str : out string);
	end component instruction_decoder;

	-----------------------------------------------------------
	--Pipeline Registers
	-----------------------------------------------------------
	component IFID_reg is
		port(D     : in  m32_IFID;      -- Input from IF stage
			 Q     : out m32_IFID;      -- Output to ID stage
			 WE    : in  m32_1bit;      -- Write enable
			 reset : in  m32_1bit;      -- The reset/flush signal
			 clock : in  m32_1bit);     -- The clock signal
	end component;

	component IDEX_reg is
		port(D     : in  m32_IDEX;      -- Input from ID stage
			 Q     : out m32_IDEX;      -- Output to EX stage
			 WE    : in  m32_1bit;      -- Write enable
			 reset : in  m32_1bit;      -- The reset/flush signal
			 clock : in  m32_1bit);     -- The clock signal
	end component;

	component EXMEM_reg is
		port(D     : in  m32_EXMEM;     -- Input from ID stage
			 Q     : out m32_EXMEM;     -- Output to EX stage
			 WE    : in  m32_1bit;      -- Write enable
			 reset : in  m32_1bit;      -- The reset/flush signal
			 clock : in  m32_1bit);     -- The clock signal
	end component;

	component MEMWB_reg is
		port(D     : in  m32_MEMWB;     -- Input from ID stage
			 Q     : out m32_MEMWB;     -- Output to EX stage
			 WE    : in  m32_1bit;      -- Write enable
			 reset : in  m32_1bit;      -- The reset/flush signal
			 clock : in  m32_1bit);     -- The clock signal
	end component;

	-- Pipeline Register Signals
	signal IFID_in, IFID_out                                                              : m32_IFID;
	signal IDEX_in, IDEX_out                                                              : m32_IDEX;
	signal EXMEM_in, EXMEM_out                                                            : m32_EXMEM;
	signal MEMWB_in, MEMWB_out                                                            : m32_MEMWB;
	signal IFID_WE, IDEX_WE, EXMEM_WE, MEMWB_WE, IFID_RST, IDEX_RST, EXMEM_RST, MEMWB_RST : m32_1bit;

	-- PC Signals
	signal PC, PCUpdate, jumporbranch, branchaddressX4, branchaddress, extended, PCPlus4, jumpaddress, jumpinstruction, jumpinstructionX4, nojumpaddress, branchorplus4 : m32_vector(DATAWIDTH - 1 downto 0) := (others => '0');

	-- Control signals
	signal zero, one, takebranch, bne, beq : m32_1bit                           := '0';
	signal s_reset, s_upperload            : m32_vector(DATAWIDTH - 1 downto 0) := (others => '0');
	signal s_alumux                        : m32_vector(2 downto 0)             := "000";
	signal s_leftshift                     : m32_vector(A - 1 downto 0)         := (others => '0');
	signal s_alucontrol_out                : m32_alucontrol_out;
	signal s_control_out                   : m32_control_out;

	--Data
	signal instruction, read1, read2, aluresult, memorydataread, registerwrite, shamt, alumux1, alumux2, writeback, loadupper, loadimmediate : m32_vector(DATAWIDTH - 1 downto 0) := (others => '0');
	signal writemux, regwritedst                                                                                                             : m32_5bits                          := (others => '0');

	--Clock
	signal CLK : m32_logic;

begin
	IFID_WE  <= '1';
	IDEX_WE  <= '1';
	EXMEM_WE <= '1';
	MEMWB_WE <= '1';
	-----------------------------------------------------------
	--Pipeline Registers
	-----------------------------------------------------------
	IFID : IFID_reg
		port map(D     => IFID_in,      -- Input from IF stage
			     Q     => IFID_out,     -- Output to ID stage
			     WE    => IFID_WE,      -- Write enable
			     reset => IFID_RST,     -- The reset/flush signal
			     clock => CLK);         -- The clock signal

	IDEX : IDEX_reg
		port map(D     => IDEX_in,      -- Input from IF stage
			     Q     => IDEX_out,     -- Output to ID stage
			     WE    => IDEX_WE,      -- Write enable
			     reset => IDEX_RST,     -- The reset/flush signal
			     clock => CLK);         -- The clock signal

	EXMEM : EXMEM_reg
		port map(D     => EXMEM_in,     -- Input from IF stage
			     Q     => EXMEM_out,    -- Output to ID stage
			     WE    => EXMEM_WE,     -- Write enable
			     reset => EXMEM_RST,    -- The reset/flush signal
			     clock => CLK);

	MEMWB : MEMWB_reg
		port map(D     => MEMWB_in,     -- Input from IF stage
			     Q     => MEMWB_out,    -- Output to ID stage
			     WE    => MEMWB_WE,     -- Write enable
			     reset => MEMWB_RST,    -- The reset/flush signal
			     clock => CLK);

	CLK <= clock;

	-----------------------------------------------------------
	--IF Stage
	-----------------------------------------------------------
	INST_DECODER : instruction_decoder
		port map(i_instr_bit => inst,
			     c_clk       => clock,
			     o_instr_str => IFID_in.inst_string);

	PCREG : register_Nbit
		generic map(N => DATAWIDTH)     -- Size of the register
		port map(i_A   => PCUpdate,     -- Data input
			     o_D   => PC,           -- Data output
			     c_WE  => '1',          -- Write enable
			     c_RST => reset,        -- The clock signal
			     c_CLK => clock);       -- The reset signal

	--Switch between previous addresses or register address for jump
	JRSWITCHER : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => s_alucontrol_out.jr,
			     i_A => jumporbranch,
			     i_B => EXMEM_out.aluresult,
			     o_D => PCUpdate);

	imem_addr    <= PC;
	IFID_in.inst <= inst;

	--Add four to PC 
	PCADDFOUR : fulladder_Nbit
		generic map(N => DATAWIDTH)
		port map(i_A => PC,
			     i_B => X"00000004",
			     i_C => '0',
			     o_D => IFID_in.pc_plus_4,
			     o_C => open);

	--Switch between PC + 4 and branch address (the result here called nojumpaddress)
	BRANCHSWITCHER : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => takebranch,
			     i_A => IFID_in.pc_plus_4,
			     i_B => EXMEM_out.branchaddress,
			     o_D => branchorplus4);

	--Switch between jump address and non-jump address
	JUMPSWITCHER : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => s_control_out.jump,
			     i_A => branchorplus4,
			     i_B => IDEX_out.jumpaddress,
			     o_D => jumporbranch);

	-----------------------------------------------------------
	-----------------------------------------------------------
	--ID Stage
	-----------------------------------------------------------
	----------------------------------------------------------- 


	--Control Forwarding
	IDEX_in.pc_plus_4   <= IFID_out.pc_plus_4;
	IDEX_in.inst_string <= IFID_out.inst_string;
	IDEX_in.inst        <= IFID_out.inst;
	IDEX_in.rs          <= IFID_out.inst(25 downto 21);
	IDEX_in.rt          <= IFID_out.inst(20 downto 16);
	IDEX_in.rd          <= IFID_out.inst(15 downto 11);

	CONTROLLER : controlv4 port map(op_code       => IFID_out.inst(31 downto 26),
			                        o_control_out => IDEX_in.control);

	WRITESWITCHER : mux_Nbit_2in
		generic map(N => 5)
		port map(c_S => MEMWB_out.control.reg_dst,
			     i_A => MEMWB_out.inst(20 downto 16),
			     i_B => MEMWB_out.inst(15 downto 11),
			     o_D => writemux);

	-- Write to return address register ($31 or $ra) for jal
	JALSWITCHER : mux_Nbit_2in
		generic map(N => 5)
		port map(c_S => IDEX_in.control.jal,
			     i_A => writemux,
			     i_B => "11111",
			     o_D => regwritedst);

	-- Select return address for writing for jalselect
	WADDRESSSWITCHER : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => IDEX_in.control.jal,
			     i_A => writeback,
			     i_B => PCPlus4,
			     o_D => registerwrite);

	-- Reset signal
	g_RESET : for I in 1 to DATAWIDTH - 1 generate
		s_reset(I) <= reset;
	end generate g_RESET;
	s_reset(0) <= '1';

	REGISTERS : registerfile_Nbit_Mreg
		generic map(N => DATAWIDTH,
			        M => 32,
			        A => 5)
		port map(i_R1a => MEMWB_out.inst(25 downto 21),
			     i_R2a => MEMWB_out.inst(20 downto 16),
			     i_Wa  => regwritedst,
			     i_A   => registerwrite,
			     o_D1o => IDEX_in.rdata1,
			     o_D2o => IDEX_in.rdata2,
			     c_WE  => MEMWB_out.control.reg_write,
			     c_RST => s_reset,
			     c_CLK => CLK);

	jumpinstruction <= "000000" & IFID_out.inst(25 downto 0);

	INSTRUCTIONSHIFTER : leftshifter_Nbit
		generic map(N => DATAWIDTH,
			        A => A)
		port map(i_A     => jumpinstruction,
			     c_Shamt => "00010",
			     o_D     => jumpinstructionX4);

	IDEX_in.jumpaddress <= PCPlus4(31 downto 28) & jumpinstructionX4(27 downto 0);

	-- Extension is for branching and immediate loading into ALUv2
	EXTENSION : extender_Nbit_Mbit
		generic map(N => 16, M => DATAWIDTH)
		port map(c_Ext => IDEX_in.control.signedload,
			     i_A   => IDEX_in.inst(15 downto 0),
			     o_D   => IDEX_in.sign_ext_imm);

	-----------------------------------------------------------
	-----------------------------------------------------------
	--EX Stage
	-----------------------------------------------------------
	-----------------------------------------------------------

	--Control Forwarding
	EXMEM_in.pc_plus_4   <= IDEX_out.pc_plus_4;
	EXMEM_in.inst_string <= IDEX_out.inst_string;
	EXMEM_in.inst        <= IDEX_out.inst;
	EXMEM_in.control     <= IDEX_out.control;
	EXMEM_in.rdata2      <= IDEX_out.rdata2;
	EXMEM_in.rd          <= IDEX_out.rd;
	EXMEM_in.rs          <= IDEX_out.rs;
	EXMEM_in.rt          <= IDEX_out.rt;

	ALUCONTROLLER : alucontrolv4
		port map(i_op      => IDEX_out.control.alu_op,
			     i_funct   => IDEX_out.inst(5 downto 0),
			     o_alucont => s_alucontrol_out);

	SHAMTEXTENDER : extender_Nbit_Mbit
		generic map(N => 5,
			        M => DATAWIDTH)
		port map(c_Ext => '1',
			     i_A   => IDEX_out.inst(10 downto 6),
			     o_D   => shamt);

	-- ALU Op is: Shift(1), Shift(0), Mux(2), Ainv, Binv & Cin, Mux(1), Mux(0)
	s_alumux <= s_alucontrol_out.alucont(4) & s_alucontrol_out.alucont(1 downto 0);
	MASTERALUv2 : ALU_Nbit
		generic map(N => DATAWIDTH)
		port map(i_A     => alumux1,
			     i_B     => alumux2,
			     i_Ainv  => s_alucontrol_out.alucont(3),
			     i_Binv  => s_alucontrol_out.alucont(2),
			     i_C     => s_alucontrol_out.alucont(2),
			     c_Op    => s_alumux,
			     c_Shift => s_alucontrol_out.alucont(6 downto 5),
			     o_D     => EXMEM_in.aluresult,
			     o_OF    => open,
			     o_Zero  => EXMEM_in.aluzero);

	s_leftshift(A - 1)                   <= '1';
	s_leftshift(A - 2 downto 0)          <= (others => '0');
	s_upperload(15 downto 0)             <= IDEX_out.inst(15 downto 0);
	s_upperload(DATAWIDTH - 1 downto 16) <= (others => '0');

	-- This is for lui - shifts instruction 15 -> 0 left by 16
	UPPERLOADER : leftshifter_Nbit
		generic map(N => DATAWIDTH,
			        A => A)
		port map(i_A     => s_upperload,
			     c_Shamt => s_leftshift,
			     o_D     => loadupper);

	-- Switch between the left-shifted immediate (for lui) or the extended immediate
	LOADUPPERSWITCHER : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(i_A => extended,
			     i_B => loadupper,
			     c_S => IDEX_out.control.upper,
			     o_D => loadimmediate);

	-- Switch between register read 1 output or the shift amount in instruction for input A of ALU
	ALUSWITCHER1 : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => s_alucontrol_out.shift,
			     i_A => IDEX_out.rdata1,
			     i_B => shamt,
			     o_D => alumux1);

	-- Switch between register read 2 output or the immediate value for input B of ALU
	ALUSWITCHER2 : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => IDEX_out.control.alu_src,
			     i_A => IDEX_out.rdata2,
			     i_B => loadimmediate,
			     o_D => alumux2);

	--BRANCHING
	BRANCHSHIFTER : leftshifter_Nbit
		generic map(N => DATAWIDTH,
			        A => A)
		port map(i_A     => IDEX_out.sign_ext_imm,
			     c_Shamt => "00010",
			     o_D     => branchaddressX4);

	--Add PC +4 to multiplied relative Branch Address to get absolute PC address
	BRANCHADDER : fulladder_Nbit
		generic map(N => DATAWIDTH)
		port map(i_A => IDEX_out.pc_plus_4,
			     i_B => branchaddressX4,
			     i_C => '0',
			     o_D => EXMEM_in.branchaddress,
			     o_C => open);

	-----------------------------------------------------------
	-----------------------------------------------------------
	--MEM Stage
	-----------------------------------------------------------   
	-----------------------------------------------------------

	--Control Forwarding
	MEMWB_in.inst_string <= EXMEM_out.inst_string;
	MEMWB_in.inst        <= EXMEM_out.inst;
	MEMWB_in.aluresult   <= EXMEM_out.aluresult;
	MEMWB_in.control     <= EXMEM_out.control;
	MEMWB_in.rd          <= EXMEM_out.rd;
	MEMWB_in.rs          <= EXMEM_out.rs;
	MEMWB_in.rt          <= EXMEM_out.rt;

	-------FIX BYTE VS WORD ADDRESS------
	dmem_addr         <= EXMEM_out.aluresult;
	dmem_read         <= EXMEM_out.control.mem_read;
	dmem_write        <= EXMEM_out.control.mem_write;
	dmem_wmask        <= "1111";        -- Data memory write mask
	MEMWB_in.mem_data <= dmem_rdata;
	dmem_wdata        <= EXMEM_out.rdata2;

	--AND branch and zero for BEQ, AND branch and not(zero) for bne
	beq        <= EXMEM_out.control.branch(0) and EXMEM_out.aluzero;
	one        <= not EXMEM_out.aluzero;
	bne        <= EXMEM_out.control.branch(1) and one;
	takebranch <= beq or bne;

	-----------------------------------------------------------
	--WB Stage
	-----------------------------------------------------------   
	WRITEBACKSWITCHER : mux_Nbit_2in
		generic map(N => DATAWIDTH)
		port map(c_S => MEMWB_out.control.mem_to_reg,
			     i_A => MEMWB_out.aluresult,
			     i_B => MEMWB_out.mem_data,
			     o_D => writeback);

end structure;