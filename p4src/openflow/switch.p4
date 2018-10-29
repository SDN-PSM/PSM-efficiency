#include <core.p4>
#include <v1model.p4>

struct intrinsic_metadata_t {
    bit<48> ingress_global_timestamp;
    bit<4>  mcast_grp;
    bit<4>  egress_rid;
    bit<16> mcast_hash;
    bit<32> lf_field_list;
    bit<16> resubmit_flag;
    bit<8>  priority;
}

struct meta_t {
    bit<16> tcpLength;
    bit<8>  cpu_msgType;
    bit<8>  cpu_deviceID;
    bit<8>  cpu_flag;
    bit<8>  cpu_portID;
    bit<48> eth_srcAddr;
    bit<48> eth_dstAddr;
    bit<32> ipv4_srcAddr;
    bit<32> ipv4_dstAddr;
    bit<16> tcp_srcPort;
    bit<16> tcp_dstPort;
    bit<32> tcp_seqNo;
    bit<32> tcp_ackNo;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<32> idx;
    bit<32> currentPathID;
    bit<32> count;
    bit<32> count_temp;
    bit<32> pathCount;
    bit<32> rttFlag;
    bit<32> packet_length;
    bit<32> vid;
}

struct queueing_metadata_t {
    bit<48> enq_timestamp;
    bit<16> enq_qdepth;
    bit<32> deq_timedelta;
    bit<16> deq_qdepth;
}

struct timestamp_t {
    bit<48> portStartTimestamp;
    bit<48> currentTimestamp;
    bit<48> MAXtimestamp;
    bit<48> resultTimestamp;
    bit<48> MAXTimestamp;
}

header arp_rarp_t {
    bit<16> hwtype;
    bit<16> protoType;
    bit<8>  hwAddrLen;
    bit<8>  protoAddrLen;
    bit<16> opcode;
}

header arp_rarp_ipv4_t {
    bit<48> srcHwAddr;
    bit<32> srcProtoAddr;
    bit<48> dstHwAddr;
    bit<32> dstProtoAddr;
}

header cpu_header_t {
    bit<32> identifier;
    bit<8>  msgType;
    bit<8>  deviceID;
    bit<8>  flag;
    bit<8>  portID;
}

header ethernet_t {
    bit<48> dstAddr;
    bit<48> srcAddr;
    bit<16> etherType;
}

header ipv4_t {
    bit<4>  version;
    bit<4>  ihl;
    bit<8>  diffserv;
    bit<16> totalLen;
    bit<16> identification;
    bit<3>  flags;
    bit<13> fragOffset;
    bit<8>  ttl;
    bit<8>  protocol;
    bit<16> hdrChecksum;
    bit<32> srcAddr;
    bit<32> dstAddr;
}

header tcp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<32> seqNo;
    bit<32> ackNo;
    bit<4>  dataOffset;
    bit<4>  res;
    bit<8>  flags;
    bit<16> window;
    bit<16> checksum;
    bit<16> urgentPtr;
}

header vlan_t {
    bit<3>  pcp;
    bit<1>  cfi;
    bit<12> vid;
    bit<16> ethType;
}

struct metadata {
    @name(".intrinsic_metadata") 
    intrinsic_metadata_t intrinsic_metadata;
    @name(".meta") 
    meta_t               meta;
    @name(".queueing_metadata") 
    queueing_metadata_t  queueing_metadata;
    @name(".timestamp") 
    timestamp_t          timestamp;
}

struct headers {
    @name(".arp_rarp") 
    arp_rarp_t      arp_rarp;
    @name(".arp_rarp_ipv4") 
    arp_rarp_ipv4_t arp_rarp_ipv4;
    @name(".cpu_header") 
    cpu_header_t    cpu_header;
    @name(".ethernet") 
    ethernet_t      ethernet;
    @name(".ipv4") 
    ipv4_t          ipv4;
    @name(".tcp") 
    tcp_t           tcp;
    @name(".vlan") 
    vlan_t          vlan;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".parse_arp_rarp") state parse_arp_rarp {
        packet.extract(hdr.arp_rarp);
        transition select(hdr.arp_rarp.protoType) {
            16w0x800: parse_arp_rarp_ipv4;
            default: accept;
        }
    }
    @name(".parse_arp_rarp_ipv4") state parse_arp_rarp_ipv4 {
        packet.extract(hdr.arp_rarp_ipv4);
        transition accept;
    }
    @name(".parse_cpu_header") state parse_cpu_header {
        packet.extract(hdr.cpu_header);
        meta.meta.cpu_msgType = hdr.cpu_header.msgType;
        meta.meta.cpu_deviceID = hdr.cpu_header.deviceID;
        meta.meta.cpu_flag = hdr.cpu_header.flag;
        meta.meta.cpu_portID = hdr.cpu_header.portID;
        transition parse_ethernet;
    }
    @name(".parse_ethernet") state parse_ethernet {
        packet.extract(hdr.ethernet);
        meta.meta.eth_srcAddr = hdr.ethernet.srcAddr;
        meta.meta.eth_dstAddr = hdr.ethernet.dstAddr;
        transition select(hdr.ethernet.etherType) {
            16w0x800: parse_ipv4;
            16w0x806: parse_arp_rarp;
            16w0x8100: parse_vlan;
            default: accept;
        }
    }
    @name(".parse_ipv4") state parse_ipv4 {
        packet.extract(hdr.ipv4);
        meta.meta.tcpLength = hdr.ipv4.totalLen - 16w20;
        meta.meta.ipv4_srcAddr = hdr.ipv4.srcAddr;
        meta.meta.ipv4_dstAddr = hdr.ipv4.dstAddr;
        transition select(hdr.ipv4.protocol) {
            8w0x6: parse_tcp;
            default: accept;
        }
    }
    @name(".parse_tcp") state parse_tcp {
        packet.extract(hdr.tcp);
        meta.meta.tcp_srcPort = hdr.tcp.srcPort;
        meta.meta.tcp_dstPort = hdr.tcp.dstPort;
        meta.meta.tcp_seqNo = hdr.tcp.seqNo;
        meta.meta.tcp_ackNo = hdr.tcp.ackNo;
        transition accept;
    }
    @name(".parse_vlan") state parse_vlan {
        packet.extract(hdr.vlan);
        transition parse_ipv4;
    }
    @name(".start") state start {
        transition select((packet.lookahead<bit<32>>())[31:0]) {
            32w0x87654321: parse_cpu_header;
            default: parse_ethernet;
        }
    }
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".setOutput") action setOutput(bit<9> port) {
        standard_metadata.egress_spec = port;
        meta.intrinsic_metadata.priority = 8w0;
    }
    @name("._drop") action _drop() {
        mark_to_drop();
    }
    @name(".ARPRouting") table ARPRouting {
        actions = {
            setOutput;
            _drop;
        }
        key = {
            hdr.arp_rarp_ipv4.srcProtoAddr: exact;
            hdr.arp_rarp_ipv4.dstProtoAddr: exact;
        }
    }
    @name(".IPv4Routing") table IPv4Routing {
        actions = {
            setOutput;
            _drop;
        }
        key = {
            hdr.ipv4.srcAddr: exact;
            hdr.ipv4.dstAddr: exact;
        }
    }
    apply {
        if (hdr.arp_rarp_ipv4.isValid()) {
            ARPRouting.apply();
        }
        if (hdr.ipv4.isValid()) {
            IPv4Routing.apply();
        }
    }
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.cpu_header);
        packet.emit(hdr.ethernet);
        packet.emit(hdr.vlan);
        packet.emit(hdr.arp_rarp);
        packet.emit(hdr.arp_rarp_ipv4);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.tcp);
    }
}

control verifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        verify_checksum(true, { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
        verify_checksum_with_payload(hdr.tcp.isValid(), { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, 8w0, hdr.ipv4.protocol, meta.meta.tcpLength, hdr.tcp.srcPort, hdr.tcp.dstPort, hdr.tcp.seqNo, hdr.tcp.ackNo, hdr.tcp.dataOffset, hdr.tcp.res, hdr.tcp.flags, hdr.tcp.window, hdr.tcp.urgentPtr }, hdr.tcp.checksum, HashAlgorithm.csum16);
    }
}

control computeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(true, { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
        update_checksum_with_payload(hdr.tcp.isValid(), { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, 8w0, hdr.ipv4.protocol, meta.meta.tcpLength, hdr.tcp.srcPort, hdr.tcp.dstPort, hdr.tcp.seqNo, hdr.tcp.ackNo, hdr.tcp.dataOffset, hdr.tcp.res, hdr.tcp.flags, hdr.tcp.window, hdr.tcp.urgentPtr }, hdr.tcp.checksum, HashAlgorithm.csum16);
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;

