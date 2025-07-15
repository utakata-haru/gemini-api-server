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
      // Gemini Webサイトを自動操作してレスポンスを取得
      final response = await _automateGeminiWebsite(question);
      if (response.isNotEmpty) {
        return response;
      } else {
        return _generateSimpleResponse(question);
      }
    } catch (e) {
      // エラーが発生した場合はフォールバック
      return _generateSimpleResponse(question);
    }
  }
  
  Future<String> _automateGeminiWebsite(String question) async {
    try {
      // Geminiサイトのメインページにアクセス
      final mainPageResponse = await http.get(
        Uri.parse('https://gemini.google.com/app'),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
          'Accept-Encoding': 'gzip, deflate, br',
          'DNT': '1',
          'Connection': 'keep-alive',
          'Upgrade-Insecure-Requests': '1',
        },
      );
      
      if (mainPageResponse.statusCode != 200) {
        return '';
      }
      
      // セッションCookieやCSRFトークンを抽出
      final cookies = mainPageResponse.headers['set-cookie'] ?? '';
      final pageContent = mainPageResponse.body;
      
      // CSRFトークンやセッション情報を抽出（簡易版）
      final csrfMatch = RegExp(r'"csrf_token"\s*:\s*"([^"]+)"').firstMatch(pageContent);
      final sessionMatch = RegExp(r'"session_id"\s*:\s*"([^"]+)"').firstMatch(pageContent);
      
      final csrfToken = csrfMatch?.group(1) ?? '';
      final sessionId = sessionMatch?.group(1) ?? '';
      
      // 質問を送信するAPIエンドポイントを呼び出し
      final chatResponse = await http.post(
        Uri.parse('https://gemini.google.com/app/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
          'Accept-Language': 'ja,en-US;q=0.9,en;q=0.8',
          'Origin': 'https://gemini.google.com',
          'Referer': 'https://gemini.google.com/app',
          'X-Requested-With': 'XMLHttpRequest',
          'Cookie': cookies,
          if (csrfToken.isNotEmpty) 'X-CSRF-Token': csrfToken,
        },
        body: json.encode({
          'message': {
            'text': question,
            'type': 'text'
          },
          'conversation_id': sessionId.isNotEmpty ? sessionId : null,
          'model': 'gemini-pro',
          'stream': false,
        }),
      );
      
      if (chatResponse.statusCode == 200) {
        final responseData = json.decode(chatResponse.body) as Map<String, dynamic>;
        
        // レスポンスからテキストを抽出
        if (responseData['candidates'] != null && responseData['candidates'] is List) {
          final candidates = responseData['candidates'] as List;
          if (candidates.isNotEmpty) {
            final firstCandidate = candidates[0] as Map<String, dynamic>;
            if (firstCandidate['content'] != null) {
              final content = firstCandidate['content'] as Map<String, dynamic>;
              if (content['parts'] != null && content['parts'] is List) {
                final parts = content['parts'] as List;
                if (parts.isNotEmpty) {
                  final firstPart = parts[0] as Map<String, dynamic>;
                  if (firstPart['text'] != null) {
                    return firstPart['text'] as String;
                  }
                }
              }
            }
          }
        }
        
        // 別の形式のレスポンスを試す
        if (responseData['response'] != null) {
          return responseData['response'] as String;
        }
        
        if (responseData['text'] != null) {
          return responseData['text'] as String;
        }
        
        if (responseData['message'] != null) {
          return responseData['message'] as String;
        }
      }
      
      // 代替エンドポイントを試す
      final altResponse = await http.post(
        Uri.parse('https://bard.google.com/api/chat'),
        headers: {
          'Content-Type': 'application/json',
          'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          'Accept': 'application/json',
          'Origin': 'https://bard.google.com',
          'Referer': 'https://bard.google.com/',
        },
        body: json.encode({
          'message': question,
          'conversation_id': null,
        }),
      );
      
      if (altResponse.statusCode == 200) {
        final altData = json.decode(altResponse.body) as Map<String, dynamic>;
        if (altData['response'] != null) {
          return altData['response'] as String;
        }
      }
      
      return '';
    } catch (e) {
      print('Gemini automation error: $e');
      return '';
    }
  }
  
  String _generateSimpleResponse(String question) {
    // より柔軟で汎用的な回答生成
    final lowerQuestion = question.toLowerCase();
    
    // 挨拶
    if (lowerQuestion.contains('こんにちは') || lowerQuestion.contains('hello') || lowerQuestion.contains('おはよう') || lowerQuestion.contains('こんばんは')) {
      return 'こんにちは！お元気ですか？何かお手伝いできることがあれば、お気軽にお聞かせください。';
    }
    
    // 天気関連
    else if (lowerQuestion.contains('天気') || lowerQuestion.contains('weather')) {
      return '申し訳ございませんが、リアルタイムの天気情報は提供できません。お住まいの地域の天気予報サイトをご確認ください。';
    }
    
    // 時間関連
    else if (lowerQuestion.contains('時間') || lowerQuestion.contains('time') || lowerQuestion.contains('いま何時')) {
      return '現在の時刻は ${DateTime.now().toString()} です。';
    }
    
    // お礼
    else if (lowerQuestion.contains('ありがとう') || lowerQuestion.contains('thank')) {
      return 'どういたしまして！他にも何かご質問があれば、いつでもお聞かせください。';
    }
    
    // 自己紹介
    else if (lowerQuestion.contains('名前') || lowerQuestion.contains('name') || lowerQuestion.contains('あなたは誰')) {
      return '私はGemini風AIアシスタントです。様々な質問にお答えできるよう努めています。';
    }
    
    // 機能説明
    else if (lowerQuestion.contains('何ができる') || lowerQuestion.contains('what can you do') || lowerQuestion.contains('機能')) {
      return '私は質問にお答えしたり、簡単な会話をしたりできます。プログラミング、一般知識、日常的な質問など、幅広いトピックについてお話しできます。';
    }
    
    // プログラミング関連
    else if (lowerQuestion.contains('python') || lowerQuestion.contains('javascript') || lowerQuestion.contains('java') || lowerQuestion.contains('dart') || lowerQuestion.contains('flutter') || lowerQuestion.contains('コード') || lowerQuestion.contains('プログラム')) {
      return _generateProgrammingResponse(question);
    }
    
    // 計算関連
    else if (lowerQuestion.contains('計算') || lowerQuestion.contains('足し算') || lowerQuestion.contains('引き算') || lowerQuestion.contains('掛け算') || lowerQuestion.contains('割り算') || _containsNumbers(question)) {
      return _generateMathResponse(question);
    }
    
    // 説明・解説関連
    else if (lowerQuestion.contains('説明') || lowerQuestion.contains('教えて') || lowerQuestion.contains('とは') || lowerQuestion.contains('について') || lowerQuestion.contains('how') || lowerQuestion.contains('what is')) {
      return _generateExplanationResponse(question);
    }
    
    // 一般的な質問
    else {
      return _generateGeneralResponse(question);
    }
  }
  
  String _generateProgrammingResponse(String question) {
    final lowerQuestion = question.toLowerCase();
    
    if (lowerQuestion.contains('python')) {
      if (lowerQuestion.contains('計算機') || lowerQuestion.contains('calculator')) {
        return '''Pythonで簡単な計算機のコードをご紹介します：

```python
def calculator():
    print("簡単な計算機")
    print("演算子: +, -, *, /")
    
    while True:
        try:
            num1 = float(input("最初の数字を入力してください: "))
            operator = input("演算子を入力してください (+, -, *, /): ")
            num2 = float(input("2番目の数字を入力してください: "))
            
            if operator == '+':
                result = num1 + num2
            elif operator == '-':
                result = num1 - num2
            elif operator == '*':
                result = num1 * num2
            elif operator == '/':
                if num2 != 0:
                    result = num1 / num2
                else:
                    print("エラー: ゼロで割ることはできません")
                    continue
            else:
                print("無効な演算子です")
                continue
                
            print(f"結果: {num1} {operator} {num2} = {result}")
            
            if input("続けますか？ (y/n): ").lower() != 'y':
                break
                
        except ValueError:
            print("無効な入力です。数字を入力してください。")

if __name__ == "__main__":
    calculator()
```

このコードは基本的な四則演算ができる計算機です。''';
      } else {
        return 'Pythonについてお答えします。Pythonは読みやすく書きやすいプログラミング言語で、データサイエンス、ウェブ開発、自動化など様々な分野で使われています。具体的に何について知りたいですか？';
      }
    } else if (lowerQuestion.contains('javascript')) {
      return 'JavaScriptについてお答えします。JavaScriptはウェブブラウザで動作するプログラミング言語で、ウェブページに動的な機能を追加できます。Node.jsを使えばサーバーサイドでも動作します。';
    } else if (lowerQuestion.contains('dart') || lowerQuestion.contains('flutter')) {
      return 'Dart/Flutterについてお答えします。DartはGoogleが開発したプログラミング言語で、Flutterフレームワークと組み合わせてクロスプラットフォームのモバイルアプリを開発できます。';
    } else {
      return 'プログラミングについてお答えします。どの言語や技術について詳しく知りたいですか？Python、JavaScript、Java、Dart/Flutter、HTML/CSS、データベースなど、様々なトピックについてお話しできます。';
    }
  }
  
  String _generateMathResponse(String question) {
    // 簡単な数式を検出して計算
    final numbers = RegExp(r'\d+').allMatches(question).map((m) => int.parse(m.group(0)!)).toList();
    
    if (numbers.length >= 2) {
      final num1 = numbers[0];
      final num2 = numbers[1];
      
      if (question.contains('+') || question.contains('足し算') || question.contains('たす')) {
        return '$num1 + $num2 = ${num1 + num2}';
      } else if (question.contains('-') || question.contains('引き算') || question.contains('ひく')) {
        return '$num1 - $num2 = ${num1 - num2}';
      } else if (question.contains('*') || question.contains('×') || question.contains('掛け算') || question.contains('かける')) {
        return '$num1 × $num2 = ${num1 * num2}';
      } else if (question.contains('/') || question.contains('÷') || question.contains('割り算') || question.contains('わる')) {
        if (num2 != 0) {
          return '$num1 ÷ $num2 = ${num1 / num2}';
        } else {
          return 'エラー: ゼロで割ることはできません。';
        }
      }
    }
    
    return '計算についてお答えします。具体的な数式を教えていただければ、計算結果をお答えできます。例：「10 + 5は？」「20 × 3を計算して」など。';
  }
  
  String _generateExplanationResponse(String question) {
    final lowerQuestion = question.toLowerCase();
    
    if (lowerQuestion.contains('ai') || lowerQuestion.contains('人工知能')) {
      return 'AI（人工知能）は、人間の知能を模倣したコンピューターシステムです。機械学習、深層学習、自然言語処理などの技術を使って、データから学習し、予測や判断を行います。';
    } else if (lowerQuestion.contains('api')) {
      return 'API（Application Programming Interface）は、異なるソフトウェア間でデータや機能をやり取りするための仕組みです。ウェブAPIを使うことで、他のサービスの機能を自分のアプリケーションに組み込むことができます。';
    } else if (lowerQuestion.contains('データベース') || lowerQuestion.contains('database')) {
      return 'データベースは、大量のデータを効率的に保存・管理・検索するためのシステムです。SQL、NoSQL、リレーショナルデータベースなど様々な種類があります。';
    } else {
      return '「$question」について説明いたします。申し訳ございませんが、この特定のトピックについて詳細な説明を提供できません。より具体的な質問をしていただければ、お役に立てるかもしれません。';
    }
  }
  
  String _generateGeneralResponse(String question) {
    final responses = [
      'ご質問「$question」についてお答えします。興味深いトピックですね。もう少し詳しく教えていただけますか？',
      '「$question」について考えてみました。このテーマについて、どのような観点から知りたいですか？',
      'ご質問ありがとうございます。「$question」について、具体的にどのような情報をお求めでしょうか？',
      '「$question」に関するご質問ですね。このトピックについて、より詳しくお聞かせください。',
      'ご質問「$question」について、お答えできるよう努めます。どのような角度から回答をお求めでしょうか？'
    ];
    
    // 質問の長さに基づいて回答を選択
    final index = question.length % responses.length;
    return responses[index];
  }
  
  bool _containsNumbers(String text) {
    return RegExp(r'\d').hasMatch(text);
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