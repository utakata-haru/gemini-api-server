import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart';
import 'package:shelf_router/shelf_router.dart';
import 'package:http/http.dart' as http;

class GeminiApiServer {
  late HttpServer _server;
  final int port;

  GeminiApiServer({this.port = 8080});

  Future<void> start() async {
    final router = Router();

    // CORS設定
    final corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    // ヘルスチェックエンドポイント
    router.get('/health', (Request request) {
      return Response.ok(
        json.encode({'status': 'ok', 'timestamp': DateTime.now().toIso8601String()}),
        headers: {'Content-Type': 'application/json', ...corsHeaders},
      );
    });

    // Gemini API エンドポイント
    router.get('/api/gemini', (Request request) async {
      try {
        final question = request.url.queryParameters['q'];
        if (question == null || question.isEmpty) {
          return Response.badRequest(
            body: json.encode({
              'error': 'Missing required parameter: q',
              'usage': '/api/gemini?q=your_question_here'
            }),
            headers: {'Content-Type': 'application/json', ...corsHeaders},
          );
        }

        // Gemini APIを呼び出す（実際のAPIキーが必要）
        final response = await _callGeminiApi(question);
        
        return Response.ok(
          json.encode({
            'question': question,
            'answer': response,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'success'
          }),
          headers: {'Content-Type': 'application/json', ...corsHeaders},
        );
      } catch (e) {
        return Response.internalServerError(
          body: json.encode({
            'error': 'Internal server error',
            'message': e.toString(),
            'timestamp': DateTime.now().toIso8601String()
          }),
          headers: {'Content-Type': 'application/json', ...corsHeaders},
        );
      }
    });

    // POST版のGemini API
    router.post('/api/gemini', (Request request) async {
      try {
        final body = await request.readAsString();
        final data = json.decode(body) as Map<String, dynamic>;
        final question = data['question'] as String?;
        
        if (question == null || question.isEmpty) {
          return Response.badRequest(
            body: json.encode({
              'error': 'Missing required field: question',
              'usage': 'POST {"question": "your_question_here"}'
            }),
            headers: {'Content-Type': 'application/json', ...corsHeaders},
          );
        }

        final response = await _callGeminiApi(question);
        
        return Response.ok(
          json.encode({
            'question': question,
            'answer': response,
            'timestamp': DateTime.now().toIso8601String(),
            'status': 'success'
          }),
          headers: {'Content-Type': 'application/json', ...corsHeaders},
        );
      } catch (e) {
        return Response.internalServerError(
          body: json.encode({
            'error': 'Internal server error',
            'message': e.toString(),
            'timestamp': DateTime.now().toIso8601String()
          }),
          headers: {'Content-Type': 'application/json', ...corsHeaders},
        );
      }
    });

    // API使用方法の説明
    router.get('/', (Request request) {
      final usage = '''
<!DOCTYPE html>
<html>
<head>
    <title>Gemini API Server</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; }
        .endpoint { background: #f5f5f5; padding: 15px; margin: 10px 0; border-radius: 5px; }
        .method { color: #007acc; font-weight: bold; }
        .url { color: #d73a49; }
        pre { background: #f6f8fa; padding: 10px; border-radius: 3px; overflow-x: auto; }
    </style>
</head>
<body>
    <h1>Gemini API Server</h1>
    <p>このサーバーは他のアプリケーションからGemini AIを利用するためのAPIを提供します。</p>
    
    <h2>利用可能なエンドポイント:</h2>
    
    <div class="endpoint">
        <h3><span class="method">GET</span> <span class="url">/health</span></h3>
        <p>サーバーの状態を確認</p>
    </div>
    
    <div class="endpoint">
        <h3><span class="method">GET</span> <span class="url">/api/gemini?q=質問内容</span></h3>
        <p>URLパラメータで質問を送信</p>
        <p><strong>例:</strong> <code>/api/gemini?q=こんにちは</code></p>
    </div>
    
    <div class="endpoint">
        <h3><span class="method">POST</span> <span class="url">/api/gemini</span></h3>
        <p>JSONボディで質問を送信</p>
        <p><strong>例:</strong></p>
        <pre>{"question": "こんにちは"}</pre>
    </div>
    
    <h2>レスポンス形式:</h2>
    <pre>{
  "question": "質問内容",
  "answer": "Geminiの回答",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "status": "success"
}</pre>
    
    <h2>使用例:</h2>
    <p><strong>curl:</strong></p>
    <pre>curl "http://localhost:8080/api/gemini?q=こんにちは"</pre>
    
    <p><strong>JavaScript:</strong></p>
    <pre>fetch('http://localhost:8080/api/gemini?q=こんにちは')
  .then(response => response.json())
  .then(data => console.log(data.answer));</pre>
</body>
</html>
''';
      return Response.ok(
        usage,
        headers: {'Content-Type': 'text/html; charset=utf-8', ...corsHeaders},
      );
    });

    // OPTIONSリクエストの処理（CORS対応）
    router.options('/<path|.*>', (Request request) {
      return Response.ok('', headers: corsHeaders);
    });

    final handler = Pipeline()
        .addMiddleware(_corsMiddleware)
        .addHandler(router.call);

    _server = await serve(handler, InternetAddress.anyIPv4, port);
    print('Gemini API Server running on http://localhost:$port');
    print('API endpoint: http://localhost:$port/api/gemini?q=your_question');
  }

  Future<String> _callGeminiApi(String question) async {
    // 注意: 実際のGemini APIを使用する場合は、APIキーが必要です
    // ここではダミーレスポンスを返しています
    
    // 実際のGemini API呼び出しの例:
    // final apiKey = Platform.environment['GEMINI_API_KEY'];
    // if (apiKey == null) {
    //   throw Exception('GEMINI_API_KEY environment variable not set');
    // }
    
    // final response = await http.post(
    //   Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent?key=$apiKey'),
    //   headers: {'Content-Type': 'application/json'},
    //   body: json.encode({
    //     'contents': [{
    //       'parts': [{'text': question}]
    //     }]
    //   }),
    // );
    
    // if (response.statusCode == 200) {
    //   final data = json.decode(response.body);
    //   return data['candidates'][0]['content']['parts'][0]['text'];
    // } else {
    //   throw Exception('Gemini API error: ${response.statusCode}');
    // }
    
    // ダミーレスポンス（テスト用）
    await Future.delayed(Duration(milliseconds: 500)); // API呼び出しをシミュレート
    return 'これはダミーレスポンスです。質問「$question」に対する回答です。実際のGemini APIを使用するには、APIキーの設定が必要です。';
  }

  // ignore: prefer_function_declarations_over_variables
  final Middleware _corsMiddleware = (Handler innerHandler) {
    return (Request request) async {
      final response = await innerHandler(request);
      return response.change(headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
        ...response.headers,
      });
    };
  };

  Future<void> stop() async {
    await _server.close();
    print('Server stopped');
  }
}

void main() async {
  // 環境変数PORTを取得、デフォルトは8080
  final port = int.tryParse(Platform.environment['PORT'] ?? '8080') ?? 8080;
  final server = GeminiApiServer(port: port);
  await server.start();
  
  // Ctrl+Cでサーバーを停止
  ProcessSignal.sigint.watch().listen((signal) async {
    print('\nShutting down server...');
    await server.stop();
    exit(0);
  });
}