import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'dart:async';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '미국 주식 정보',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        scaffoldBackgroundColor: const Color(0xFFCDCFD1),
        useMaterial3: true,
      ),
      home: const StockSearchPage(),
    );
  }
}

class StockSearchPage extends StatefulWidget {
  const StockSearchPage({super.key});

  @override
  State<StockSearchPage> createState() => _StockSearchPageState();
}

class _StockSearchPageState extends State<StockSearchPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final List<Map<String, dynamic>> stocksList = [];
  bool isLoading = false;
  String? errorMessage;

  Future<void> _getStockInfo(String symbol) async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      _controller.clear();
      _focusNode.requestFocus();

      if (stocksList.any((stock) => stock['symbol'] == symbol.toUpperCase())) {
        setState(() {
          errorMessage = '이미 추가된 종목입니다.';
          isLoading = false;
        });
        return;
      }

      // 첫 번째 URL 시도
      var response = await http.get(
        Uri.parse('https://query2.finance.yahoo.com/v8/finance/chart/$symbol'),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('요청 시간이 초과되었습니다.');
        },
      );

      // 첫 번째 URL이 실패하면 대체 URL 시도
      if (response.statusCode != 200) {
        response = await http.get(
          Uri.parse('https://query1.finance.yahoo.com/v8/finance/chart/$symbol'),
        ).timeout(
          const Duration(seconds: 10),
          onTimeout: () {
            throw TimeoutException('요청 시간이 초과되었습니다.');
          },
        );
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['chart']['result'] != null) {
          final result = data['chart']['result'][0];
          final quote = result['indicators']['quote'][0];
          final meta = result['meta'];
          
          setState(() {
            stocksList.insert(0, {
              'symbol': symbol.toUpperCase(),
              'currentPrice': meta['regularMarketPrice'],
              'previousClose': meta['previousClose'],
              'yearStartPrice': quote['close'][0],
            });
          });
        } else {
          setState(() {
            errorMessage = '해당 심볼의 주식 정보를 찾을 수 없습니다.';
          });
        }
      } else {
        setState(() {
          errorMessage = '데이터를 불러오는데 실패했습니다. (${response.statusCode})';
        });
      }
    } on TimeoutException {
      setState(() {
        errorMessage = '요청 시간이 초과되었습니다. 다시 시도해주세요.';
      });
    } catch (e) {
      setState(() {
        errorMessage = '네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요.';
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Widget _buildTableHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF414142),
        borderRadius: BorderRadius.all(Radius.circular(10)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              '종목',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '현재가',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '년초가',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '등락률',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 40), // 삭제 버튼 공간
        ],
      ),
    );
  }

  Widget _buildStockRow(Map<String, dynamic> stock) {
    final numberFormat = NumberFormat('#,##0.00');
    final changePercent = _calculateChangePercent(
      stock['currentPrice'],
      stock['yearStartPrice'],
    );
    final percentValue = double.parse(changePercent);
    final percentColor = percentValue >= 0 ? Colors.blue : Colors.red;

    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.grey[300]!,
            width: 1.0,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Text(
                stock['symbol'],
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '\$${numberFormat.format(stock['currentPrice'])}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '\$${numberFormat.format(stock['yearStartPrice'])}',
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 16),
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '$changePercent%',
                textAlign: TextAlign.right,
                style: TextStyle(
                  fontSize: 16,
                  color: percentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(
              width: 40,
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () {
                  setState(() {
                    stocksList.remove(stock);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '미국 주식 검색',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: const Color(0xFF414142),
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.only(
          top: 24.0,
          left: 16.0,
          right: 16.0,
          bottom: 16.0,
        ),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              focusNode: _focusNode,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: '티커 심볼 입력',
                hintText: '예: AAPL, MSFT',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    if (_controller.text.isNotEmpty) {
                      _getStockInfo(_controller.text.toUpperCase());
                    }
                  },
                ),
              ),
              onSubmitted: (value) {
                if (value.isNotEmpty) {
                  _getStockInfo(value.toUpperCase());
                }
              },
              onChanged: (value) {
                final cursorPos = _controller.selection;
                _controller.text = value.toUpperCase();
                _controller.selection = cursorPos;
              },
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const CircularProgressIndicator()
            else if (errorMessage != null)
              Text(
                errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            if (stocksList.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: const Color(0xFFE4E6EB),
                      width: 1.0,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE4E6EB).withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
              _buildTableHeader(),
              Expanded(
                child: ListView.builder(
                  itemCount: stocksList.length,
                  itemBuilder: (context, index) {
                    return _buildStockRow(stocksList[index]);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        color: const Color(0xFF414142),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '© 2024 USA Stock Ticker  |  Made by 나종춘',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _calculateChangePercent(double current, double start) {
    final changePercent = ((current - start) / start) * 100;
    return NumberFormat('##0.00').format(changePercent);
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }
}
