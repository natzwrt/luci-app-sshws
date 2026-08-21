include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-sshws
PKG_VERSION:=1.0.1
PKG_RELEASE:=1

LUCI_TITLE:=LuCI Support for SSH WS Tunneling
LUCI_DEPENDS:=+python3-light +sshpass +openssh-client +badvpn-tun2socks
LUCI_PKGARCH:=all

include $(TOPDIR)/feeds/luci/luci.mk

define Package/luci-app-sshws/install
	# Memastikan struktur direktori terbuat di dalam IPK
	$(INSTALL_DIR) $(1)/usr/lib/lua/luci
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/sshws

	# Menyalin file konfigurasi default
	$(INSTALL_CONF) ./root/etc/config/sshws $(1)/etc/config/sshws
	
	# Menyalin script procd dan memberikan hak eksekusi
	$(INSTALL_BIN) ./root/etc/init.d/sshws $(1)/etc/init.d/sshws
	
	# Menyalin script core dan python injector
	$(INSTALL_BIN) ./root/usr/bin/sshws-core.sh $(1)/usr/bin/sshws-core.sh
	$(INSTALL_BIN) ./root/usr/bin/sshws-injector.py $(1)/usr/bin/sshws-injector.py
	
	# Menyalin file JSON registrasi LuCI
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-sshws.json $(1)/usr/share/luci/menu.d/luci-app-sshws.json
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-sshws.json $(1)/usr/share/rpcd/acl.d/luci-app-sshws.json
	
	# Menyalin file Javascript UI
	$(INSTALL_DATA) ./www/luci-static/resources/view/sshws/settings.js $(1)/www/luci-static/resources/view/sshws/settings.js
endef

# call BuildPackage wajib diletakkan setelah define install
# (Namun karena kita pakai luci.mk, biasanya tidak perlu dipanggil manual. 
# Jika masih error, kita akan pakai format Makefile OpenWrt standar).