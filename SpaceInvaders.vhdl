library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use ieee.std_logic_unsigned.all;
library UNISIM;
use UNISIM.VComponents.all;

entity Lab5 is
    Port ( sys_clk : in std_logic;
          reset_btn   : in std_logic;
          TMDS, TMDSB : out std_logic_vector(3 downto 0));
end Lab5;

architecture Behavioral of Lab5 is

-- Video Timing Parameters
--1280x720@60HZ
constant HPIXELS_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(1280, 11)); --Horizontal Live Pixels
constant VLINES_HDTV720P  : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(720, 11));  --Vertical Live ines
constant HSYNCPW_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(80, 11));  --HSYNC Pulse Width
constant VSYNCPW_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(5, 11));    --VSYNC Pulse Width
constant HFNPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(72, 11));   --Horizontal Front Porch
constant VFNPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(3, 11));    --Vertical Front Porch
constant HBKPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(216, 11));  --Horizontal Front Porch
constant VBKPRCH_HDTV720P : std_logic_vector(10 downto 0) := std_logic_vector(to_unsigned(22, 11));   --Vertical Front Porch

constant pclk_M : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(36, 8));
constant pclk_D : std_logic_vector(7 downto 0) := std_logic_vector(to_unsigned(24, 8)); 

constant tc_hsblnk: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1);
constant tc_hssync: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1 + HFNPRCH_HDTV720P);
constant tc_hesync: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1 + HFNPRCH_HDTV720P + HSYNCPW_HDTV720P);
constant tc_heblnk: std_logic_vector(10 downto 0) := (HPIXELS_HDTV720P - 1 + HFNPRCH_HDTV720P + HSYNCPW_HDTV720P + HBKPRCH_HDTV720P);
constant tc_vsblnk: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1);
constant tc_vssync: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1 + VFNPRCH_HDTV720P);
constant tc_vesync: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1 + VFNPRCH_HDTV720P + VSYNCPW_HDTV720P);
constant tc_veblnk: std_logic_vector(10 downto 0) := (VLINES_HDTV720P - 1 + VFNPRCH_HDTV720P + VSYNCPW_HDTV720P + VBKPRCH_HDTV720P);
signal sws_clk: std_logic_vector(3 downto 0); --clk synchronous output
signal sws_clk_sync: std_logic_vector(3 downto 0); --clk synchronous output
signal bgnd_hblnk : std_logic;
signal bgnd_vblnk : std_logic;

signal red_data, green_data, blue_data : std_logic_vector(7 downto 0) := (others => '0');
signal hcount, vcount : std_logic_vector(10 downto 0);
signal hsync, vsync, active : std_logic;
signal pclk : std_logic;
signal clkfb : std_logic;
signal rgb_data : std_logic_vector(23 downto 0) := (others => '0');

-- Colors
-- White
constant COLORW_RED : std_logic_vector(7 downto 0) := x"FF";
constant COLORW_GREEN : std_logic_vector(7 downto 0) := x"FF";
constant COLORW_BLUE : std_logic_vector(7 downto 0) := x"FF";

-- Green
constant COLOR1_RED : std_logic_vector(7 downto 0) := x"00";
constant COLOR1_GREEN : std_logic_vector(7 downto 0) := x"FF";
constant COLOR1_BLUE : std_logic_vector(7 downto 0) := x"00";

-- type state_type is (Color1, Color2, Color3, Color4);            --FSM States for Shields
-- signal state : state_type := Color1;
constant rst : std_logic := '0';
signal mclk_sig : std_logic ;
signal internal_counter : integer := 1;
signal slow_clock : std_logic := '0';
signal Hslow_clock : std_logic := '0';
signal Qslow_clock : std_logic := '0';
constant radius : integer := 15;
signal middleH : integer := 640;                -- Will be Incremented by 10 each 1/4 Slow Clock
signal middleV : integer := 360;                -- "
signal InvaderDirection : std_logic := '1';

type state_shield is (five, four, three, two, one, zero);                                 
signal shield1 : state_shield := five;                                
signal shield2 : state_shield := five;                               
signal shield3 : state_shield := five;                                 
signal shield4 : state_shield := five;


begin

pixel_clock_gen : entity work.pxl_clk_gen port map (
    clk_in1 => sys_clk,
    clk_out1 => pclk,
    locked => open,
    reset => rst
);

timing_inst : entity work.timing port map (
	tc_hsblnk=>tc_hsblnk, --input
	tc_hssync=>tc_hssync, --input
	tc_hesync=>tc_hesync, --input
	tc_heblnk=>tc_heblnk, --input
	hcount=>hcount, --output
	hsync=>hsync, --output
	hblnk=>bgnd_hblnk, --output
	tc_vsblnk=>tc_vsblnk, --input
	tc_vssync=>tc_vssync, --input
	tc_vesync=>tc_vesync, --input
	tc_veblnk=>tc_veblnk, --input
	vcount=>vcount, --output
	vsync=>vsync, --output
	vblnk=>bgnd_vblnk, --output
	restart=>reset_btn,
	clk=>pclk);
	
hdmi_controller : entity work.rgb2dvi 
    generic map (
        kClkRange => 2
    )
    port map (
        TMDS_Clk_p => TMDS(3),
        TMDS_Clk_n => TMDSB(3),
        TMDS_Data_p => TMDS(2 downto 0),
        TMDS_Data_n => TMDSB(2 downto 0),
        aRst => '0',
        aRst_n => '1',
        vid_pData => rgb_data,
        vid_pVDE => active,
        vid_pHSync => hsync,
        vid_pVSync => vsync,
        PixelClk => pclk, 
        SerialClk => '0');
        
        
active <= not(bgnd_hblnk) and not(bgnd_vblnk); 
rgb_data <= red_data & green_data & blue_data;	 

count_proc : process(pclk)                                          -- Slow Clock Pulse Process TODO DEFINITELY CAN CLEAN UP THE IF STATEMENTS
begin
    if rising_edge(pclk) then
        -- Increment your internal counter
        internal_counter <= internal_counter + 1;
        if internal_counter = 74250000 then
            -- Set slow_clock High, Increment Slow clock, reset internal_counter
            slow_clock <= '1';
            internal_counter <= 0;
        else
            -- Set slow_clock Low 
            slow_clock <= '0';
        end if;
        
        if internal_counter = 37125000 then         -- 1/2 Slow Clock, used for Invader Movement
            Hslow_clock <= '1';
            
            if (middleH + 150) >= 1250 then
                InvaderDirection <= '0';            -- Move Left
                middleV <= middleV - 30;            -- Move the Invaders down one spot on boarder contact
            elsif (middleH - 150) <= 30 then
                InvaderDirection <= '1';            -- Move Right
                middleV <= middleV - 30;            -- Move the Invaders down one spot on boarder contact
            end if;
            
            if InvaderDirection = '0' then
                middleH <= middleH - 10;            -- Move Invaders Right by 10
            elsif InvaderDirection = '1' then
                middleH <= middleH + 10;            -- Move Invaders Left by 10
            end if;
        else
            -- Set slow_clock Low 
            Hslow_clock <= '0';
        end if;
        
        if internal_counter = 18562500 then         -- 1/4 Slow Clock, used for Player Movement   
            Qslow_clock <= '1';
        else
            -- Set slow_clock Low 
            Qslow_clock <= '0';
        end if;
    end if;
end process count_proc;

process(pclk)
begin
    if rising_edge(pclk) then
    
    end if;
end process;


process(hcount, vcount)                                             -- Draws out all of our invaders. 
begin

      -- First Row of Squares
      if ( (((middleH - 150) <= hcount AND hcount <= (middleH - 120)) OR ((middleH - 105) <= hcount AND hcount <= (middleH - 75)) OR ((middleH - 60) <= hcount AND hcount <= (middleH - 30)) OR ((middleH - 15) <= hcount AND hcount <= (middleH + 15)) OR ((middleH + 30) <= hcount AND hcount <= (middleH + 60)) OR ((middleH + 75) <= hcount AND hcount <= (middleH + 105)) OR ((middleH + 120) <= hcount AND hcount <= (middleH + 150))) AND (middleV <= vcount AND vcount <= middleV + 30)) then
          red_data <= COLORW_RED;
          green_data <= COLORW_GREEN;
          blue_data <= COLORW_BLUE;
      elsif ( (middleV <= vcount AND vcount <= middleV + 30) ) then
          red_data <= (others => '0');
          green_data <= (others => '0');
          blue_data <= (others => '0');
      end if;
      
      -- Second Row of Squares
      if ( (((middleH - 150) <= hcount AND hcount <= (middleH - 120)) OR ((middleH - 105) <= hcount AND hcount <= (middleH - 75)) OR ((middleH - 60) <= hcount AND hcount <= (middleH - 30)) OR ((middleH - 15) <= hcount AND hcount <= (middleH + 15)) OR ((middleH + 30) <= hcount AND hcount <= (middleH + 60)) OR ((middleH + 75) <= hcount AND hcount <= (middleH + 105)) OR ((middleH + 120) <= hcount AND hcount <= (middleH + 150))) AND (middleV + 60 <= vcount AND vcount <= middleV + 90)) then
          red_data <= COLORW_RED;
          green_data <= COLORW_GREEN;
          blue_data <= COLORW_BLUE;
      elsif ( (middleV + 60 <= vcount AND vcount <= middleV + 90) ) then
          red_data <= (others => '0');
          green_data <= (others => '0');
          blue_data <= (others => '0');
      end if;
      
      -- First Row of Circles
      
end process;
     
end Behavioral;

