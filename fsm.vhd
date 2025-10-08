BEGIN

      PROCESS (CLK, RESET)
      BEGIN
      IF RESET = '1' THEN
            Current_State <= S_IDLE;
            State_Count <= 0;
            BUSY_OUT      <= '0'; 

      ELSIF rising_edge(CLK) THEN
  
