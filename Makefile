include $(TOPDIR)/rules.mk

PKG_NAME:=luci-app-sshws
PKG_VERSION:=1.0.2
PKG_RELEASE:=1

# Menggunakan format package standar (Bukan luci.mk)
include $(INCLUDE_DIR)/package.mk

define Package/luci-app-sshws
  SECTION:=luci
  CATEGORY:=LuCI
  SUBMENU:=3. Applications
  TITLE:=LuCI Support for SSH WS Tunneling
  DEPENDS:=+python3-light +sshpass +openssh-client +badvpn-tun2socks
  PKGARCH:=all
endef

# Mencegah SDK mencari kode bahasa C untuk di-compile
define Build/Compile
endef

# Instruksi paksa untuk memasukkan file ke dalam .ipk
define Package/luci-app-sshws/install
	$(INSTALL_DIR) $(1)/etc/config
	$(INSTALL_DIR) $(1)/etc/init.d
	$(INSTALL_DIR) $(1)/usr/bin
	$(INSTALL_DIR) $(1)/usr/share/luci/menu.d
	$(INSTALL_DIR) $(1)/usr/share/rpcd/acl.d
	$(INSTALL_DIR) $(1)/www/luci-static/resources/view/sshws

	$(INSTALL_CONF) ./root/etc/config/sshws $(1)/etc/config/sshws
	$(INSTALL_BIN) ./root/etc/init.d/sshws $(1)/etc/init.d/sshws
	$(INSTALL_BIN) ./root/usr/bin/sshws-core.sh $(1)/usr/bin/sshws-core.sh
	$(INSTALL_BIN) ./root/usr/bin/sshws-injector.py $(1)/usr/bin/sshws-injector.py
	
	$(INSTALL_DATA) ./root/usr/share/luci/menu.d/luci-app-sshws.json $(1)/usr/share/luci/menu.d/luci-app-sshws.json
	$(INSTALL_DATA) ./root/usr/share/rpcd/acl.d/luci-app-sshws.json $(1)/usr/share/rpcd/acl.d/luci-app-sshws.json
	$(INSTALL_DATA) ./www/luci-static/resources/view/sshws/settings.js $(1)/www/luci-static/resources/view/sshws/settings.js
endef

$(eval $(call BuildPackage,luci-app-sshws))