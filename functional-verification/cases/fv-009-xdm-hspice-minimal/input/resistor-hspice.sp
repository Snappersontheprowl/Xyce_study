* FV-009 XDM HSPICE-like minimal resistor test
.option post
V1 1 0 DC 1
R1 1 0 1k
.op
.print dc V(1) I(V1)
.end
