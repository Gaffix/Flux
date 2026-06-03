from flask import Flask, request, jsonify
from flask_cors import CORS
import yt_dlp
import os
import sys
from pyngrok import ngrok

app = Flask(__name__)
CORS(app)

@app.route('/get_audio', methods=['GET'])
def get_audio():
    video_id = request.args.get('id')
    if not video_id:
        return jsonify({"error": "No ID provided"}), 400

    video_url = f"https://www.youtube.com/watch?v={video_id}"
    
    ydl_opts = {
        'format': 'bestaudio/best',
        'quiet': True,
        'no_warnings': True,
        'force_generic_extractor': False,
    }

    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(video_url, download=False)
            audio_url = info['url']
            return jsonify({
                "title": info.get('title'),
                "url": audio_url
            })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    PORT = 9000
    
    # Pega o Token do Ngrok das variáveis de ambiente do Docker
    NGROK_TOKEN = os.environ.get("NGROK_AUTHTOKEN")
    
    if NGROK_TOKEN:
        print("\n[Flux] Configurando túnel Ngrok automático...")
        ngrok.set_auth_token(NGROK_TOKEN)
        # Abre o túnel HTTP na porta configurada
        public_url = ngrok.connect(PORT)
        print("\n" + "="*60)
        print(f"🚀 LINK PARA COLOCAR NO APLICATIVO FLUX:\n👉 {public_url.public_url} 👈")
        print("="*60 + "\n")
    else:
        print("\n⚠️ NGROK_AUTHTOKEN não foi informado. Rodando apenas localmente.")

    # Executa o servidor Flask
    app.run(host='0.0.0.0', port=PORT)