#include "includes.p4"
control MyIngress(inout headers hdr,inout metadata meta,inout standard_metadata_t standard_metadata) {
action forward(bit<9> port) { standard_metadata.egress_spec = port; }
action drop() { mark_to_drop(); }
bit<9> port_tmp=9w0;
action m_forward(inout bit<9> p, bit<9> p1) { p = p1; }
table composed_t { key = { hdr.ipv4.dstAddr : exact; } actions = { m_forward(port_tmp); drop; } }
table t_1 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_2 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_3 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_4 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_5 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_6 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_7 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_8 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_9 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_10 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_11 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_12 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_13 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_14 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_15 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_16 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_17 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_18 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_19 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_20 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_21 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_22 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_23 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_24 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_25 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_26 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_27 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_28 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_29 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_30 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_31 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
table t_32 { key = { hdr.ipv4.dstAddr : exact; } actions = { forward; drop; } }
apply {
t_1.apply();
t_2.apply();
t_3.apply();
t_4.apply();
t_5.apply();
t_6.apply();
t_7.apply();
t_8.apply();
t_9.apply();
t_10.apply();
t_11.apply();
t_12.apply();
t_13.apply();
t_14.apply();
t_15.apply();
t_16.apply();
t_17.apply();
t_18.apply();
t_19.apply();
t_20.apply();
t_21.apply();
t_22.apply();
t_23.apply();
t_24.apply();
t_25.apply();
t_26.apply();
t_27.apply();
t_28.apply();
t_29.apply();
t_30.apply();
t_31.apply();
t_32.apply();
}}
V1Switch(MyParser(),MyVerifyChecksum(),MyIngress(),MyEgress(),MyComputeChecksum(),MyDeparser()) main;
