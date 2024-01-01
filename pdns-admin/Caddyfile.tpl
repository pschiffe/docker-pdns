{
	http_port 8080
	https_port 8443
}

{{ if all .SSL_MAIN_DOMAIN .SSL_EXTRA_DOMAINS -}}
{{ .SSL_EXTRA_DOMAINS }} {
	redir https://{{ .SSL_MAIN_DOMAIN }}
}
{{ end -}}

{{ .SSL_MAIN_DOMAIN | default ":8080" }} {
	@staticfiles {
		path *.jpeg *.jpg *.png *.gif *.bmp *.ico *.svg *.tif *.tiff *.css *.js *.htm *.html *.ttf *.otf *.webp *.woff *.woff2 *.txt *.csv *.rtf *.doc *.docx *.xls *.xlsx *.ppt *.pptx *.odf *.odp *.ods *.odt *.pdf *.psd *.ai *.eot *.eps *.ps *.zip *.tar *.tgz *.gz *.rar *.bz2 *.7z *.aac *.m4a *.mp3 *.mp4 *.ogg *.wav *.wma *.3gp *.avi *.flv *.m4v *.mkv *.mov *.mp4 *.mpeg *.mpg *.wmv *.exe *.iso *.dmg *.swf
	}

	log {
		output stdout
		format json
	}

	@blocked {
		path */.*
	}
	respond @blocked 404

	encode zstd gzip

	header X-Content-Type-Options "nosniff"
	header X-Frame-Options "SAMEORIGIN"
	header @staticfiles Cache-Control "public, max-age=604800, must-revalidate"
	header -Server
	header -X-Powered-By

	root * /opt/powerdns-admin/powerdnsadmin

	route {
		file_server @staticfiles {
			pass_thru
		}
		reverse_proxy 127.0.0.1:9494
	}
}
