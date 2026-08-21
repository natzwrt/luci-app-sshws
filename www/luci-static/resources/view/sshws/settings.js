'use strict';
'require view';
'require form';

// Ini adalah script UI untuk merender halaman "admin/services/sshws"
return view.extend({
	render: function() {
		var m, s, o;

		// 1. Memanggil file database /etc/config/sshws
		// m = form.Map('nama_file_config', 'Judul Halaman', 'Deskripsi Halaman')
		m = new form.Map('sshws', _('SSH WebSocket Injector'), _('Aplikasi Tunneling SSH dengan dukungan Custom Payload (CDN SNI) khusus OpenWrt 23.'));

		// 2. Membuat Section (Bagian)
		// Membaca "config global 'main'" dari file uci
		s = m.section(form.TypedSection, 'global', _('Pengaturan Akun & Server'));
		s.anonymous = true;   // true = nama 'main' tidak akan ditampilkan
		s.addremove = false;  // false = user tidak bisa menghapus section ini

		// 3. Menambahkan Input Fields (Opsi-opsi)
		
		// Toggle Enable (Centang)
		o = s.option(form.Flag, 'enabled', _('Enable Tunnel'));
		o.rmempty = false; // rmempty = remove empty (jangan hapus jika kosong)

		// Input IP Server / VPS
		o = s.option(form.Value, 'server_ip', _('Server / CDN IP'));
		o.rmempty = false;
		o.placeholder = '104.18.x.x';

		// Input Port
		o = s.option(form.Value, 'port', _('WS Port'), _('Biasanya menggunakan port 80 atau 443.'));
		o.datatype = 'port';
		o.rmempty = false;

		// Username & Password SSH
		o = s.option(form.Value, 'username', _('Username SSH'));
		o.rmempty = false;

		o = s.option(form.Value, 'password', _('Password SSH'));
		o.password = true; // Akan disensor jadi titik-titik (***)
		o.rmempty = false;

		// Input Bug Host (SNI)
		o = s.option(form.Value, 'sni', _('Bug Host / SNI'), _('Host yang akan dituju untuk trik CDN.'));
		o.placeholder = 'cdn.bug.com';
		o.rmempty = false;

		// Textarea Custom Payload
		o = s.option(form.TextValue, 'payload', _('Custom Payload'), 
			_('Gunakan variabel berikut: <b>[host]</b>, <b>[port]</b>, <b>[sni]</b>, <b>[crlf]</b>. <br/>Pastikan diakhiri dengan [crlf][crlf]'));
		o.rows = 5;          // Tinggi kotak teks (5 baris)
		o.monospace = true;  // Menggunakan font code (Courier/Monospace)
		o.rmempty = false;

		// Local Socks Port (Port lokal di router)
		o = s.option(form.Value, 'local_socks_port', _('Local SOCKS5 Port'), _('Port yang akan digunakan oleh ncat (default: 1080)'));
		o.datatype = 'port';
		o.default = '1080';
		o.rmempty = false;

		// 4. Render semua konfigurasi form
		return m.render();
	}
});