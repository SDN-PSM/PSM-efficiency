#include <core.p4>
#include <v1model.p4>

struct intrinsic_metadata_t {
    bit<4>  mcast_grp;
    bit<4>  egress_rid;
    bit<16> mcast_hash;
    bit<32> lf_field_list;
}

struct ingress_metadata_t {
    bit<8> round;
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

header paxos_t {
    bit<8>   msgtype;
    bit<16>  instance;
    bit<8>   round;
    bit<8>   vround;
    bit<64>  acceptor;
    bit<512> value;
}

header udp_t {
    bit<16> srcPort;
    bit<16> dstPort;
    bit<16> length_;
    bit<16> checksum;
}

struct metadata {
    @name(".intrinsic_metadata") 
    intrinsic_metadata_t intrinsic_metadata;
    @name(".paxos_packet_metadata") 
    ingress_metadata_t   paxos_packet_metadata;
}

struct headers {
    @name(".ethernet") 
    ethernet_t ethernet;
    @name(".ipv4") 
    ipv4_t     ipv4;
    @name(".paxos") 
    paxos_t    paxos;
    @name(".udp") 
    udp_t      udp;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".parse_ethernet") state parse_ethernet {
        packet.extract(hdr.ethernet);
        transition select(hdr.ethernet.etherType) {
            16w0x800: parse_ipv4;
            default: accept;
        }
    }
    @name(".parse_ipv4") state parse_ipv4 {
        packet.extract(hdr.ipv4);
        transition select(hdr.ipv4.protocol) {
            8w0x11: parse_udp;
            default: accept;
        }
    }
    @name(".parse_paxos") state parse_paxos {
        packet.extract(hdr.paxos);
        transition accept;
    }
    @name(".parse_udp") state parse_udp {
        packet.extract(hdr.udp);
        transition select(hdr.udp.dstPort) {
            16w0x8888: parse_paxos;
            default: accept;
        }
    }
    @name(".start") state start {
        transition parse_ethernet;
    }
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("._nop") action _nop() {
    }
    @name("._drop") action _drop() {
        mark_to_drop();
    }
    @name(".mcast_src_pruning") table mcast_src_pruning {
        actions = {
            _nop;
            _drop;
        }
        key = {
            standard_metadata.instance_type: exact;
        }
        size = 1;
    }
    apply {
        if (standard_metadata.ingress_port == standard_metadata.egress_port) {
            mcast_src_pruning.apply();
        }
    }
}

@name(".datapath_id") register<bit<64>>(32w1) datapath_id;

@name(".rounds_register") register<bit<8>>(32w65536) rounds_register;

@name(".values_register") register<bit<512>>(32w65536) values_register;

@name(".vrounds_register") register<bit<8>>(32w65536) vrounds_register;

@name("mac_learn_digest") struct mac_learn_digest {
    bit<48> srcAddr;
    bit<9>  ingress_port;
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name(".forward") action forward(bit<9> port) {
        standard_metadata.egress_spec = port;
    }
    @name(".broadcast") action broadcast() {
        meta.intrinsic_metadata.mcast_grp = 4w1;
    }
    @name("._drop") action _drop() {
        mark_to_drop();
    }
    @name(".mac_learn") action mac_learn() {
        digest<mac_learn_digest>((bit<32>)1024, { hdr.ethernet.srcAddr, standard_metadata.ingress_port });
    }
    @name("._nop") action _nop() {
    }
    @name(".handle_1a") action handle_1a() {
        hdr.paxos.msgtype = 8w2;
        vrounds_register.read(hdr.paxos.vround, (bit<32>)hdr.paxos.instance);
        values_register.read(hdr.paxos.value, (bit<32>)hdr.paxos.instance);
        datapath_id.read(hdr.paxos.acceptor, (bit<32>)0);
        rounds_register.write((bit<32>)hdr.paxos.instance, (bit<8>)hdr.paxos.round);
    }
    @name(".handle_2a") action handle_2a() {
        hdr.paxos.msgtype = 8w4;
        rounds_register.write((bit<32>)hdr.paxos.instance, (bit<8>)hdr.paxos.round);
        vrounds_register.write((bit<32>)hdr.paxos.instance, (bit<8>)hdr.paxos.round);
        values_register.write((bit<32>)hdr.paxos.instance, (bit<512>)hdr.paxos.value);
        datapath_id.read(hdr.paxos.acceptor, (bit<32>)0);
    }
    @name(".read_round") action read_round() {
        rounds_register.read(meta.paxos_packet_metadata.round, (bit<32>)hdr.paxos.instance);
    }
    @name(".dmac") table dmac {
        actions = {
            forward;
            broadcast;
        }
        key = {
            hdr.ethernet.dstAddr: exact;
        }
        size = 512;
    }
    @name(".drop_tbl") table drop_tbl {
        actions = {
            _drop;
        }
        size = 1;
    }
    @name(".smac") table smac {
        actions = {
            mac_learn;
            _nop;
        }
        key = {
            hdr.ethernet.srcAddr: exact;
        }
        size = 512;
    }
    @name(".tbl_acceptor") table tbl_acceptor {
        actions = {
            handle_1a;
            handle_2a;
            _drop;
        }
        key = {
            hdr.paxos.msgtype: exact;
        }
    }
    @name(".tbl_rnd") table tbl_rnd {
        actions = {
            read_round;
        }
    }
    apply {
        smac.apply();
        dmac.apply();
        if (hdr.paxos.isValid()) {
            tbl_rnd.apply();
            if (meta.paxos_packet_metadata.round <= hdr.paxos.round) {
                tbl_acceptor.apply();
            }
            else {
                drop_tbl.apply();
            }
        }
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit(hdr.ethernet);
        packet.emit(hdr.ipv4);
        packet.emit(hdr.udp);
        packet.emit(hdr.paxos);
    }
}

control verifyChecksum(inout headers hdr, inout metadata meta) {
    apply {
        verify_checksum(true, { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
        verify_checksum_with_payload(hdr.udp.isValid(), { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, 8w0, hdr.ipv4.protocol, hdr.udp.length_, hdr.udp.srcPort, hdr.udp.dstPort, hdr.udp.length_ }, hdr.udp.checksum, HashAlgorithm.csum16);
    }
}

control computeChecksum(inout headers hdr, inout metadata meta) {
    apply {
        update_checksum(true, { hdr.ipv4.version, hdr.ipv4.ihl, hdr.ipv4.diffserv, hdr.ipv4.totalLen, hdr.ipv4.identification, hdr.ipv4.flags, hdr.ipv4.fragOffset, hdr.ipv4.ttl, hdr.ipv4.protocol, hdr.ipv4.srcAddr, hdr.ipv4.dstAddr }, hdr.ipv4.hdrChecksum, HashAlgorithm.csum16);
        update_checksum_with_payload(hdr.udp.isValid(), { hdr.ipv4.srcAddr, hdr.ipv4.dstAddr, 8w0, hdr.ipv4.protocol, hdr.udp.length_, hdr.udp.srcPort, hdr.udp.dstPort, hdr.udp.length_ }, hdr.udp.checksum, HashAlgorithm.csum16);
    }
}

V1Switch(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;

