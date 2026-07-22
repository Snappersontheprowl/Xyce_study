** Translated using xdm 2.7.0 on Jul_22_2026_23_49_57_PM
** from /tmp/_MEIfYO3Wv/hspice.xml
** to /tmp/_MEIfYO3Wv/xyce.xml



.OPTIONS DEVICE TEMP=25 TNOM=25  ; converted options using xdm
** FV-009 XDM HSPICE-like minimal resistor test
* .option post; HSpice Parser Retained (as a comment). Continuing.
V1 1 0 DC 1
R1 1 0 R=1k
.OP

.PRINT DC FORMAT=PROBE V(1) I(V1)  ; aggregated using xdm
.END
