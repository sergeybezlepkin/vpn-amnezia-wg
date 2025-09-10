# Automatic installation and configuration of Amnezia VPN server with web interface, node monitoring, with encryption on a free domain name

<div align="center">
  <img src="/docs/screenshots/clear-amnz.png" width="50%" /> 
</div>

The predecessor of [AmneziaWG](https://docs.amnezia.org/documentation/amnezia-wg), WireGuard, has established itself as a fast and reliable VPN protocol thanks to its compact codebase and high efficiency. However, its fixed packet headers and predictable packet sizes create an easily recognizable signature. DPI systems can effortlessly identify these packets and immediately terminate connections—a critical issue in countries with strict internet censorship.

### Key Advantages
- Invisibility to DPI — dynamic headers and randomized packet sizes.
- Protocol Masking — mimics QUIC, DNS, SIP, and other UDP protocols.
- High Performance — operates as a Linux kernel module, with encryption using the single-pass AEAD algorithm ChaCha20-Poly1305 optimized with SIMD, identical to WireGuard.
- Energy Efficiency — Go-based implementation running in user space without heavy cryptography, making it suitable for mobile devices and routers.
- Cross-platform Support — compatible with all major operating systems.
- UDP Transport — all traffic transmitted over UDP, simplifying circumvention of censorship and reducing latency.

##
<div align="center">
  <img src="/docs/screenshots/menu.PNG" width="80%" /> 
</div>

##
