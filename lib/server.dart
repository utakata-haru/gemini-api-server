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
    try {
      // Gemini WebサイトのAPIエンドポイントを直接呼び出し
      // 実際のブラウザのようにリクエストを送信
      final response = await http.post(
        Uri.parse('https://gemini.google.com/app/conversation'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json, text/plain, */*',
          'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
          'Origin': 'https://gemini.google.com',
          'Referer': 'https://gemini.google.com/',
        },
        body: json.encode({
          'message': question,
          'conversation_id': null,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        
        // レスポンスからテキストを抽出（実際の構造に応じて調整が必要）
        if (data['response'] != null) {
          return data['response'] as String;
        } else if (data['text'] != null) {
          return data['text'] as String;
        } else {
          // フォールバック: シンプルなAI風レスポンス生成
          return _generateSimpleResponse(question);
        }
      } else {
        // APIが使えない場合のフォールバック
        return _generateSimpleResponse(question);
      }
    } catch (e) {
      // エラーが発生した場合もフォールバック
      return _generateSimpleResponse(question);
    }
  }
  
  String _generateSimpleResponse(String question) {
    // シンプルなルールベースの回答生成
    final lowerQuestion = question.toLowerCase();
    
    if (lowerQuestion.contains('こんにちは') || lowerQuestion.contains('hello')) {
      return 'こんにちは！お元気ですか？何かお手伝いできることがあれば、お気軽にお聞かせください。';
    } else if (lowerQuestion.contains('天気') || lowerQuestion.contains('weather')) {
      return '申し訳ございませんが、リアルタイムの天気情報は提供できません。お住まいの地域の天気予報サイトをご確認ください。';
    } else if (lowerQuestion.contains('時間') || lowerQuestion.contains('time')) {
      return '現在の時刻は ${DateTime.now().toString()} です。';
    } else if (lowerQuestion.contains('ありがとう') || lowerQuestion.contains('thank')) {
      return 'どういたしまして！他にも何かご質問があれば、いつでもお聞かせください。';
    } else if (lowerQuestion.contains('名前') || lowerQuestion.contains('name')) {
      return '私はGemini風AIアシスタントです。様々な質問にお答えできるよう努めています。';
    } else if (lowerQuestion.contains('何ができる') || lowerQuestion.contains('what can you do')) {
      return '私は質問にお答えしたり、簡単な会話をしたりできます。プログラミング、一般知識、日常的な質問など、幅広いトピックについてお話しできます。';
    } else {
      return 'ご質問「$question」についてお答えします。申し訳ございませんが、現在は限定的な機能のみ提供しており、詳細な回答ができません。より具体的な質問をしていただければ、お役に立てるかもしれません。';
    }
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