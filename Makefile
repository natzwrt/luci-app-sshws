include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-sshws
PKG_VERSION:=1.0.0
PKG_RELEASE:=1

LUCI_TITLE:=LuCI for SSH WS CDN Tunneling
LUCI_DEPENDS:=+python3-light +sshpass +openssh-client
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

# call BuildPackage - OpenWrt buildroot signature