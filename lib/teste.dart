import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // O ID de um vídeo para testar (ex: Never Gonna Give You Up)
  const String testVideoId = 'dQw4w9WgXcQ';
  
  // O endereço do seu servidor Python
  const String serverUrl = 'http://10.0.28.126:9000/get_audio?id=$testVideoId';

  print('--- INICIANDO TESTE DE CONEXÃO ---');
  print('Solicitando para: $serverUrl');

  try {
    // Faz a requisição GET
    final response = await http.get(Uri.parse(serverUrl));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      
      print('\n✅ SUCESSO!');
      print('Título do Vídeo: ${data['title']}');
      print('URL do Áudio extraída:');
      print('-------------------------------------------');
      print(data['url']);
      print('-------------------------------------------');
      print('\nCopie o link acima e cole no seu navegador.');
      print('Se ele começar a tocar a música, o backend está 100%!');
    } else {
      print('\n❌ ERRO NO SERVIDOR');
      print('Status Code: ${response.statusCode}');
      print('Corpo da resposta: ${response.body}');
    }
  } catch (e) {
    print('\n❌ ERRO DE CONEXÃO');
    print('Não foi possível alcançar o servidor.');
    print('Verifique se o server.py está rodando e se o IP está correto.');
    print('Erro: $e');
  }
}