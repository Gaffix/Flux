from flask import Flask, request, jsonify
from flask_cors import CORS
import yt_dlp
import os
import sys
from pyngrok import ngrok
from cachetools import cached, TTLCache

app = Flask(__name__)
CORS(app)

# Cria um cache na memória para guardar os URLs extraídos.
# Guarda até 1000 músicas. Expira a cada 4 horas (14400 segundos) pois os links do YouTube expiram.
url_cache = TTLCache(maxsize=1000, ttl=14400)

@cached(url_cache)
def extract_youtube_audio_info(video_id, quality="normal"):
    video_url = f"https://www.youtube.com/watch?v={video_id}"
    
    format_str = 'bestaudio/best'
    if quality == 'lossless':
        format_str = 'bestaudio[acodec=flac]/bestaudio[acodec=opus]/bestaudio/best'
    elif quality == 'high':
        format_str = 'bestaudio[abr>128]/bestaudio/best'
    elif quality == 'low':
        format_str = 'worstaudio/worst'

    ydl_opts = {
        'format': format_str,
        'quiet': True,
        'no_warnings': True,
        'force_generic_extractor': False,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        info = ydl.extract_info(video_url, download=False)
        return {
            "title": info.get('title'),
            "url": info['url']
        }

@app.route('/get_audio', methods=['GET'])
def get_audio():
    video_id = request.args.get('id')
    quality = request.args.get('quality', 'normal')
    if not video_id:
        return jsonify({"error": "No ID provided"}), 400

    try:
        # Tenta pegar do cache primeiro, ou busca no yt-dlp
        data = extract_youtube_audio_info(video_id, quality)
        return jsonify(data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/search', methods=['GET'])
def search():
    query = request.args.get('q')
    if not query:
        return jsonify({"error": "No query provided"}), 400
    
    try:
        ydl_opts = {
            'quiet': True,
            'extract_flat': True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"ytsearch1:{query} audio", download=False)
            if 'entries' in info and len(info['entries']) > 0:
                video = info['entries'][0]
                return jsonify({
                    "video_id": video.get('id'),
                    "title": video.get('title')
                })
            else:
                return jsonify({"error": "No results found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/trending', methods=['GET'])
def trending():
    query = request.args.get('q', 'Top Hits Music 2024')
    try:
        ydl_opts = {
            'quiet': True,
            'extract_flat': True,
        }
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(f"ytsearch15:{query}", download=False)
            results = []
            if 'entries' in info:
                for video in info['entries']:
                    if video.get('id'):
                        results.append({
                            "video_id": video.get('id'),
                            "title": video.get('title'),
                            "channel": video.get('uploader')
                        })
            return jsonify(results)
    except Exception as e:
        return jsonify({"error": str(e)}), 500

PORT = 9000

# Pega o Token do Ngrok das variáveis de ambiente do Docker
NGROK_TOKEN = os.environ.get("NGROK_AUTHTOKEN")

# Verifica se não está rodando no reloader do Flask para evitar abrir dois túneis
if NGROK_TOKEN and os.environ.get("WERKZEUG_RUN_MAIN") != "true":
    print("\n[Flux] Configurando túnel Ngrok automático...")
    ngrok.set_auth_token(NGROK_TOKEN)
    
    # Pega o domínio das variáveis de ambiente (se existir)
    NGROK_DOMAIN = os.environ.get("NGROK_DOMAIN")
    
    if NGROK_DOMAIN:
        print(f"[Flux] Usando domínio estático: {NGROK_DOMAIN}")
        # Abre o túnel usando o domínio fixo reservado
        public_url = ngrok.connect(PORT, domain=NGROK_DOMAIN)
    else:
        print("[Flux] Nenhum domínio informado. Gerando link aleatório...")
        # Abre o túnel padrão (gera link aleatório)
        public_url = ngrok.connect(PORT)
        
    print("\n" + "="*60)
    print(f"🚀 LINK PARA COLOCAR NO FLUX APP:\n👉 {public_url.public_url} 👈")
    print("="*60 + "\n")

if __name__ == '__main__':
    # Executa o servidor Flask
    app.run(host='0.0.0.0', port=PORT)