-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2022 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Matyas Strelec <xstrel03 AT stud.fit.vutbr.cz>
--
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_arith.ALL;
USE ieee.std_logic_unsigned.ALL;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
ENTITY cpu IS
	PORT (
		CLK : IN STD_LOGIC; -- hodinovy signal
		RESET : IN STD_LOGIC; -- asynchronni reset procesoru
		EN : IN STD_LOGIC; -- povoleni cinnosti procesoru

		-- synchronni pamet RAM
		DATA_ADDR : OUT STD_LOGIC_VECTOR(12 DOWNTO 0); -- adresa do pameti
		DATA_WDATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
		DATA_RDATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
		DATA_RDWR : OUT STD_LOGIC; -- cteni (0) / zapis (1)
		DATA_EN : OUT STD_LOGIC; -- povoleni cinnosti

		-- vstupni port
		IN_DATA : IN STD_LOGIC_VECTOR(7 DOWNTO 0); -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
		IN_VLD : IN STD_LOGIC; -- data platna
		IN_REQ : OUT STD_LOGIC; -- pozadavek na vstup data

		-- vystupni port
		OUT_DATA : OUT STD_LOGIC_VECTOR(7 DOWNTO 0); -- zapisovana data
		OUT_BUSY : IN STD_LOGIC; -- LCD je zaneprazdnen (1), nelze zapisovat
		OUT_WE : OUT STD_LOGIC -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'
	);
END cpu;
-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
ARCHITECTURE behavioral OF cpu IS

	-- pc register
	SIGNAL pc_reg : STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL pc_inc : STD_LOGIC;
	SIGNAL pc_dec : STD_LOGIC;

	-- ptr register
	SIGNAL ptr_reg : STD_LOGIC_VECTOR(12 DOWNTO 0);
	SIGNAL ptr_inc : STD_LOGIC;
	SIGNAL ptr_dec : STD_LOGIC;

	-- cnt register
	SIGNAL cnt_reg : STD_LOGIC_VECTOR(7 DOWNTO 0);
	SIGNAL cnt_inc : STD_LOGIC;
	SIGNAL cnt_dec : STD_LOGIC;

	-- mx
	SIGNAL mx_1_select : STD_LOGIC;
	SIGNAL mx_2_select : STD_LOGIC_VECTOR(1 DOWNTO 0);

	-- fsm states
	TYPE state_fsm IS (
		S_BEGIN,
		S_FETCH,
		S_DECODE,

		S_PTR_INC,
		S_PTR_INC_2,

		S_PTR_DEC,
		S_PTR_DEC_2,

		S_PC_INC,
		S_PC_INC_2,
		S_PC_INC_3,

		S_PC_DEC,
		S_PC_DEC_2,
		S_PC_DEC_3,

		S_WHILE,
		S_WHILE_2,
		S_WHILE_3,
		S_WHILE_4,
		S_WHILE_5,

		S_WHILE_END,
		S_WHILE_END_2,
		S_WHILE_END_3,
		S_WHILE_END_4,
		S_WHILE_END_5,
		S_WHILE_END_6,
		S_WHILE_END_7,

		S_DO_WHILE,

		S_DO_WHILE_END,

		S_WRITE,
		S_WRITE_2,
		S_WRITE_3,

		S_READ,
		S_READ_2,
		S_READ_3,

		S_HALT,

		S_OTHER
	);

	SIGNAL state_now : state_fsm;
	SIGNAL state_next : state_fsm;

BEGIN
	--ptr
	ptr : PROCESS (CLK, RESET, ptr_inc, ptr_dec, ptr_reg)
	BEGIN
		IF RESET = '1' THEN
			ptr_reg <= "1000000000000";
		ELSIF rising_edge(CLK) THEN
			IF ptr_inc = '1'AND ptr_reg = "1111111111111" THEN
				ptr_reg <= "1000000000000";
			ELSIF ptr_inc = '1' THEN
				ptr_reg <= ptr_reg + 1;
			ELSIF ptr_dec = '1' AND ptr_reg = "1000000000000" THEN
				ptr_reg <= "1111111111111";
			ELSIF ptr_dec = '1' THEN
				ptr_reg <= ptr_reg - 1;
			END IF;
		END IF;
	END PROCESS;
	-- ptr

	-- pc
	pc : PROCESS (CLK, RESET, pc_inc, pc_dec, pc_reg)
	BEGIN
		IF RESET = '1' THEN
			pc_reg <= (OTHERS => '0');
		ELSIF rising_edge(CLK) THEN
			IF pc_inc = '1' THEN
				pc_reg <= pc_reg + 1;
			ELSIF pc_dec = '1' THEN
				pc_reg <= pc_reg - 1;
			END IF;
		END IF;
	END PROCESS;
	-- pc

	--cnt
	cnt : PROCESS (CLK, RESET, cnt_inc, cnt_dec, cnt_reg)
	BEGIN
		IF RESET = '1' THEN
			cnt_reg <= "00000000";
		ELSIF rising_edge(CLK) THEN
			IF cnt_inc = '1' THEN
				cnt_reg <= cnt_reg + 1;
			ELSIF cnt_dec = '1' THEN
				cnt_reg <= cnt_reg - 1;
			END IF;
		END IF;
	END PROCESS;
	-- cnt

	-- mx_1
	mx_1 : PROCESS (mx_1_select, pc_reg, ptr_reg)
	BEGIN
		CASE mx_1_select IS
			WHEN '0' => DATA_ADDR <= pc_reg;
			WHEN '1' => DATA_ADDR <= ptr_reg;
			WHEN OTHERS =>
		END CASE;
	END PROCESS;
	-- mx_1

	-- mx_2
	mx_2 : PROCESS (mx_2_select, IN_DATA, DATA_RDATA)
	BEGIN
		CASE mx_2_select IS
			WHEN "00" => DATA_WDATA <= IN_DATA;
			WHEN "01" => DATA_WDATA <= DATA_RDATA - 1;
			WHEN "10" => DATA_WDATA <= DATA_RDATA + 1;
			WHEN "11" => DATA_WDATA <= DATA_RDATA;
			WHEN OTHERS =>
		END CASE;
	END PROCESS;
	-- mx_2

	-- fsm		
	fsm : PROCESS (CLK, RESET)
	BEGIN
		IF RESET = '1' THEN
			state_now <= S_BEGIN;
		ELSIF rising_edge(CLK) THEN
			IF EN = '1' THEN
				state_now <= state_next;
			END IF;
		END IF;
	END PROCESS;
	-- fsm

	-- fsm_next
	fsm_next : PROCESS (IN_VLD, OUT_BUSY, DATA_RDATA, cnt_reg, state_now)

	BEGIN
		-- initialize
		DATA_EN <= '0';
		DATA_RDWR <= '0';
		IN_REQ <= '0';
		OUT_WE <= '0';

		pc_inc <= '0';
		pc_dec <= '0';

		cnt_inc <= '0';
		cnt_dec <= '0';

		ptr_inc <= '0';
		ptr_dec <= '0';

		mx_1_select <= '0';
		mx_2_select <= "00";

		-- state machine
		-- decide next state
		CASE state_now IS

				-- start reading the input
			WHEN S_BEGIN =>
				state_next <= S_FETCH;

				-- get ready to read instruction
			WHEN S_FETCH =>
				mx_1_select <= '0';
				DATA_EN <= '1';
				state_next <= S_DECODE;

				-- read instruction given in DATA_RDATA
			WHEN S_DECODE =>
				mx_1_select <= '0';
				CASE DATA_RDATA IS
					WHEN X"3E" => state_next <= S_PTR_INC;
					WHEN X"3C" => state_next <= S_PTR_DEC;

					WHEN X"2B" => state_next <= S_PC_INC;
					WHEN X"2D" => state_next <= S_PC_DEC;

					WHEN X"5B" => state_next <= S_WHILE;
					WHEN X"5D" => state_next <= S_WHILE_END;

					WHEN X"28" => state_next <= S_DO_WHILE;
					WHEN X"29" => state_next <= S_DO_WHILE_END;

					WHEN X"2E" => state_next <= S_WRITE;
					WHEN X"2C" => state_next <= S_READ;

					WHEN X"00" => state_next <= S_HALT;
					WHEN OTHERS => state_next <= S_OTHER;
				END CASE;

				-- >
			WHEN S_PTR_INC =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				ptr_inc <= '1';
				state_next <= S_PTR_INC_2;

			WHEN S_PTR_INC_2 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- <	
			WHEN S_PTR_DEC =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				ptr_dec <= '1';
				state_next <= S_PTR_DEC_2;

			WHEN S_PTR_DEC_2 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- +
			WHEN S_PC_INC =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				state_next <= S_PC_INC_2;

			WHEN S_PC_INC_2 =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				mx_1_select <= '1';
				mx_2_select <= "10";
				state_next <= S_PC_INC_3;

			WHEN S_PC_INC_3 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- -
			WHEN S_PC_DEC =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				state_next <= S_PC_DEC_2;

			WHEN S_PC_DEC_2 =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				mx_1_select <= '1';
				mx_2_select <= "01";
				state_next <= S_PC_DEC_3;

			WHEN S_PC_DEC_3 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- .
			WHEN S_WRITE =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				state_next <= S_WRITE_2;

			WHEN S_WRITE_2 =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				IF OUT_BUSY = '0' THEN
					OUT_WE <= '1';
					OUT_DATA <= DATA_RDATA;
					state_next <= S_WRITE_3;
				ELSIF OUT_BUSY = '1' THEN
					state_next <= S_WRITE_2;
				END IF;

			WHEN S_WRITE_3 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- ,					
			WHEN S_READ =>
				IN_REQ <= '1';
				state_next <= S_READ_2;

			WHEN S_READ_2 =>
				IN_REQ <= '1';
				IF IN_VLD = '0' THEN
					state_next <= S_READ_2;
				ELSIF IN_VLD = '1' THEN
					DATA_EN <= '1';
					DATA_RDWR <= '1';
					mx_1_select <= '1';
					mx_2_select <= "00";
					state_next <= S_READ_3;
				END IF;

			WHEN S_READ_3 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- [
			WHEN S_WHILE =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				pc_inc <= '1';
				mx_1_select <= '1';
				state_next <= S_WHILE_2;

			WHEN S_WHILE_2 =>
				IF DATA_RDATA = X"00" THEN
					cnt_inc <= '1';
					state_next <= S_WHILE_3;
				ELSE
					state_next <= S_FETCH;
				END IF;

			WHEN S_WHILE_3 =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '0';
				state_next <= S_WHILE_4;

			WHEN S_WHILE_4 =>
				pc_inc <= '1';
				IF DATA_RDATA = X"5B" OR DATA_RDATA = X"28" THEN
					cnt_inc <= '1';
				ELSIF DATA_RDATA = X"5D" OR DATA_RDATA = X"29" THEN
					cnt_dec <= '1';
				END IF;
				state_next <= S_WHILE_5;

			WHEN S_WHILE_5 =>
				IF cnt_reg = "00000000" THEN
					state_next <= S_FETCH;
				ELSE
					state_next <= S_WHILE_3;
				END IF;

				-- ]
			WHEN S_WHILE_END =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				state_next <= S_WHILE_END_2;

			WHEN S_WHILE_END_2 =>
				IF DATA_RDATA = X"00" THEN
					state_next <= S_WHILE_END_3;
				ELSE
					cnt_inc <= '1';
					pc_dec <= '1';
					state_next <= S_WHILE_END_4;
				END IF;

			WHEN S_WHILE_END_3 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

			WHEN S_WHILE_END_4 =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '0';
				state_next <= S_WHILE_END_5;

			WHEN S_WHILE_END_5 =>
				IF DATA_RDATA = X"5B" OR DATA_RDATA = X"28" THEN
					cnt_dec <= '1';
				ELSIF DATA_RDATA = X"5D" OR DATA_RDATA = X"29" THEN
					cnt_inc <= '1';
				END IF;
				state_next <= S_WHILE_END_6;

			WHEN S_WHILE_END_6 =>
				IF cnt_reg = "00000000" THEN
					state_next <= S_WHILE_END_7;
				ELSE
					pc_dec <= '1';
					state_next <= S_WHILE_END_4;
				END IF;

			WHEN S_WHILE_END_7 =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- (
				-- this instruction is acting like a comment in Brainfuck
			WHEN S_DO_WHILE =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

				-- )
				-- this instruction the exact same logic as ]
				-- therefore, no need to write it again
				-- just use states for while instruction
			WHEN S_DO_WHILE_END =>
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				mx_1_select <= '1';
				state_next <= S_WHILE_END_2;

				-- halt 
			WHEN S_HALT =>
				pc_inc <= '0';
				pc_dec <= '0';
				state_next <= S_HALT;

				-- default
			WHEN S_OTHER =>
				mx_1_select <= '0';
				pc_inc <= '1';
				state_next <= S_FETCH;

			WHEN OTHERS =>

		END CASE;
	END PROCESS;
	-- fsm_next

END behavioral;