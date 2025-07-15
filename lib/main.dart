import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:flutter/foundation.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ブラウザアプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const BrowserPage(),
    );
  }
}

class BrowserPage extends StatefulWidget {
  const BrowserPage({super.key});

  @override
  State<BrowserPage> createState() => _BrowserPageState();
}

class _BrowserPageState extends State<BrowserPage> {
  WebViewController? _controller;
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _questionController = TextEditingController();
  String _geminiResponse = '';
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      _controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..addJavaScriptChannel(
          'GeminiChannel',
          onMessageReceived: (JavaScriptMessage message) {
            setState(() {
              _geminiResponse = message.message;
            });
          },
        )
        ..loadRequest(Uri.parse('https://gemini.google.com'));
      _urlController.text = 'https://gemini.google.com';
    } else {
      _urlController.text = 'Web版ではWebViewは利用できません';
    }
  }

  void _loadUrl() {
    if (kIsWeb) {
      setState(() {
        _geminiResponse = 'Web版ではWebViewによるURL読み込みは利用できません';
      });
      return;
    }
    
    final url = _urlController.text;
    if (url.isNotEmpty && _controller != null) {
      Uri uri;
      if (url.startsWith('http://') || url.startsWith('https://')) {
        uri = Uri.parse(url);
      } else {
        uri = Uri.parse('https://$url');
      }
      _controller!.loadRequest(uri);
    }
  }

  void _sendQuestionToGemini() async {
    if (kIsWeb) {
      setState(() {
        _geminiResponse = 'Web版ではGemini連携機能は利用できません。モバイル版またはデスクトップ版をご利用ください。';
      });
      return;
    }
    
    final question = _questionController.text;
    if (question.isNotEmpty && !_isProcessing && _controller != null) {
      setState(() {
        _isProcessing = true;
      });
      
      try {
        // Geminiページに質問を送信するJavaScriptを実行
        await _controller!.runJavaScript("""
          (function() {
            try {
              // Geminiの入力フィールドを探して質問を入力
              const inputField = document.querySelector('textarea[placeholder*="メッセージ"], textarea[placeholder*="質問"], textarea[data-testid="textbox"], .ql-editor, div[contenteditable="true"]');
              if (inputField) {
                // 既存のテキストをクリア
                inputField.value = '';
                inputField.textContent = '';
                inputField.innerHTML = '';
                
                // 新しい質問を設定
                inputField.value = '$question';
                inputField.textContent = '$question';
                inputField.innerHTML = '$question';
                
                // フォーカスを設定
                inputField.focus();
                
                // 入力イベントを発火
                inputField.dispatchEvent(new Event('input', { bubbles: true }));
                inputField.dispatchEvent(new Event('change', { bubbles: true }));
                inputField.dispatchEvent(new KeyboardEvent('keydown', { bubbles: true }));
                inputField.dispatchEvent(new KeyboardEvent('keyup', { bubbles: true }));
                
                // 送信ボタンを探してクリック
                setTimeout(() => {
                  const sendButtons = document.querySelectorAll('button[aria-label*="送信"], button[data-testid="send-button"], button[type="submit"], button svg');
                  for (let button of sendButtons) {
                    const parentButton = button.closest('button');
                    if (parentButton && !parentButton.disabled && parentButton.offsetParent !== null) {
                      parentButton.click();
                      break;
                    }
                  }
                }, 1000);
                
                return 'success';
              } else {
                return 'input field not found';
              }
            } catch (error) {
              return 'error: ' + error.message;
            }
          })()
        """);
        
        _questionController.clear();
      } catch (e) {
        print('JavaScript execution error: $e');
      } finally {
        // 3秒後に処理フラグをリセット
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
      }
    }
  }

  void _extractGeminiResponse() async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      if (kIsWeb) {
        // Web版では直接JavaScriptの結果を取得
        final result = await _controller?.runJavaScriptReturningResult("""
          (function() {
            try {
              // 複数のセレクターで回答要素を探す
              const selectors = [
                '[data-message-author-role="model"] .markdown',
                '[data-message-author-role="model"]',
                '.model-response',
                '.response-content',
                '[role="presentation"] div[data-message-author-role="model"]',
                'div[data-message-author-role="model"] div'
              ];
              
              let responseElements = [];
              for (let selector of selectors) {
                responseElements = document.querySelectorAll(selector);
                if (responseElements.length > 0) break;
              }
              
              if (responseElements.length > 0) {
                const latestResponse = responseElements[responseElements.length - 1];
                const responseText = latestResponse.innerText || latestResponse.textContent || latestResponse.innerHTML;
                if (responseText && responseText.trim().length > 0) {
                  return responseText.trim();
                } else {
                  return '回答が空でした';
                }
              } else {
                return '回答要素が見つかりませんでした';
              }
            } catch (error) {
              return 'エラー: ' + error.message;
            }
          })()
        """);
        
        setState(() {
          _geminiResponse = result.toString();
        });
      } else {
        // モバイル版ではJavaScriptChannelを使用
        await _controller?.runJavaScript("""
          (function() {
            try {
              // 複数のセレクターで回答要素を探す
              const selectors = [
                '[data-message-author-role="model"] .markdown',
                '[data-message-author-role="model"]',
                '.model-response',
                '.response-content',
                '[role="presentation"] div[data-message-author-role="model"]',
                'div[data-message-author-role="model"] div'
              ];
              
              let responseElements = [];
              for (let selector of selectors) {
                responseElements = document.querySelectorAll(selector);
                if (responseElements.length > 0) break;
              }
              
              if (responseElements.length > 0) {
                const latestResponse = responseElements[responseElements.length - 1];
                const responseText = latestResponse.innerText || latestResponse.textContent || latestResponse.innerHTML;
                if (responseText && responseText.trim().length > 0) {
                  GeminiChannel.postMessage(responseText.trim());
                } else {
                  GeminiChannel.postMessage('回答が空でした');
                }
              } else {
                GeminiChannel.postMessage('回答要素が見つかりませんでした');
              }
            } catch (error) {
              GeminiChannel.postMessage('エラー: ' + error.message);
            }
          })()
        """);
      }
    } catch (e) {
      setState(() {
        _geminiResponse = 'JavaScript実行エラー: $e';
      });
    } finally {
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('Geminiブラウザ'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        decoration: const InputDecoration(
                          hintText: 'URLを入力してください',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _loadUrl(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _loadUrl,
                      child: const Text('移動'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _questionController,
                        decoration: const InputDecoration(
                          hintText: 'Geminiに質問を入力してください',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        onSubmitted: (_) => _sendQuestionToGemini(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _sendQuestionToGemini,
                      child: _isProcessing 
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('質問'),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _extractGeminiResponse,
                      child: const Text('回答取得'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      body: _geminiResponse.isNotEmpty
          ? Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Geminiの回答:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        _geminiResponse,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            )
          : const Center(
              child: Text(
                'Geminiに質問を入力して「質問」ボタンを押してください',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
              ),
            ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _questionController.dispose();
    super.dispose();
  }
}
