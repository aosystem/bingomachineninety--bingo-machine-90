import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:bingomachineninety/ad_banner_widget.dart';
import 'package:bingomachineninety/ad_manager.dart';
import 'package:bingomachineninety/l10n/app_localizations.dart';
import 'package:bingomachineninety/loading_screen.dart';
import 'package:bingomachineninety/model.dart';
import 'package:bingomachineninety/text_to_speech.dart';
import 'package:bingomachineninety/theme_color.dart';

class CardPage extends StatefulWidget {
  const CardPage({super.key});
  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  late final AdManager _adManager;
  late ThemeColor _themeColor;
  bool _ready = false;
  bool _isFirst = true;
  //
  List<List<int?>> _housieCard = [];
  final TextEditingController _freeText1Controller = TextEditingController();
  final TextEditingController _freeText2Controller = TextEditingController();
  final TextEditingController _freeText3Controller = TextEditingController();
  late List<List<_CardCell>> _grid;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    _adManager = AdManager();
    _grid = List.generate(3,(_) => List.generate(9,(_) => _CardCell(number:0)));
    await Model.ensureReady();
    _freeText1Controller.text = Model.freeText1;
    _freeText2Controller.text = Model.freeText2;
    _freeText3Controller.text = Model.freeText3;
    await TextToSpeech.applyPreferences(Model.ttsVoiceId,Model.ttsVolume);
    final stored = Model.cardState;
    final bool restored = _loadStoredState(stored);
    if (!restored) {
      _generateNewCard();
      unawaited(_saveCardState());
    }
    if (mounted) {
      setState(() {
        _ready = true;
      });
    }
  }

  @override
  void dispose() {
    unawaited(TextToSpeech.stop());
    _adManager.dispose();
    _freeText1Controller.dispose();
    _freeText2Controller.dispose();
    _freeText3Controller.dispose();
    super.dispose();
  }

  void _generateNewCard() {
    _housieCard = List.generate(3, (_) => List<int?>.filled(9, 0));
    List<List<int>> columnPools = List.generate(9, (colIndex) {
      int start = colIndex * 10 + 1;
      int end = (colIndex == 8) ? 90 : start + 9;
      return List.generate(end - start + 1, (i) => start + i)..shuffle();
    });
    List<int> rowCounts = List.filled(3, 0);
    List<int> colCounts = List.filled(9, 0);
    for (int col = 0; col < 9; col++) {
      int rowToPlace = Random().nextInt(3);
      _housieCard[rowToPlace][col] = columnPools[col].removeAt(0);
      rowCounts[rowToPlace]++;
      colCounts[col]++;
    }
    bool changed = true;
    while (changed) {
      changed = false;
      for (int r = 0; r < 3; r++) {
        while (rowCounts[r] < 5) {
          List<int> potentialCols = List.generate(9, (index) => index)..shuffle();
          bool addedToRow = false;
          for (int c in potentialCols) {
            if (_housieCard[r][c] == 0 && colCounts[c] < 3) {
              if (columnPools[c].isNotEmpty) {
                _housieCard[r][c] = columnPools[c].removeAt(0);
                rowCounts[r]++;
                colCounts[c]++;
                addedToRow = true;
                changed = true;
                break;
              }
            }
          }
          if (!addedToRow) {
            break;
          }
        }
      }
    }
    for (int r = 0; r < 3; r++) {
      while (rowCounts[r] > 5) {
        List<int> colsInRow = [];
        for (int c = 0; c < 9; c++) {
          if (_housieCard[r][c] != 0) {
            colsInRow.add(c);
          }
        }
        colsInRow.shuffle();
        bool removedFromRow = false;
        for (int c in colsInRow) {
          if (colCounts[c] > 1) {
            _housieCard[r][c] = 0;
            rowCounts[r]--;
            colCounts[c]--;
            removedFromRow = true;
            changed = true;
            break;
          }
        }
        if (!removedFromRow) {
          break;
        }
      }
    }
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 9; col++) {
        _grid[row][col].number = _housieCard[row][col]!;
      }
    }
    setState(() {});
  }

  bool _loadStoredState(String stored) {
    if (stored.isEmpty) {
      return false;
    }
    final entries = stored
      .split(',')
      .where((element) => element.isNotEmpty)
      .toList();
    if (entries.length < 9 * 3) {
      return false;
    }
    int index = 0;
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 9; col++) {
        final parts = entries[index].split(':');
        final number = int.tryParse(parts[0]) ?? 0;
        final isOpen = parts.length > 1 && parts[1].toLowerCase() == 'true';
        _grid[row][col]
          ..number = number
          ..open = isOpen;
        index++;
      }
    }
    return true;
  }

  Future<void> _saveCardState() async {
    final buffer = StringBuffer();
    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 9; col++) {
        final cell = _grid[row][col];
        buffer
          ..write(cell.number)
          ..write(':')
          ..write(cell.open)
          ..write(',');
      }
    }
    await Model.setCardState(buffer.toString());
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const LoadingScreen();
    }
    if (_isFirst) {
      _isFirst = false;
      _themeColor = ThemeColor(context: context);
    }
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: _themeColor.cardBackColor,
      appBar: AppBar(
        title: Text(l.participantMode),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(left: 8, right: 8, top: 8, bottom: 100),
                  child: Column(
                    children: [
                      _buildGrid(),
                      _buildFreeText(),
                    ],
                  ),
                ),
              )
            )
          ]
        )
      ),
      bottomNavigationBar: AdBannerWidget(adManager: _adManager),
    );
  }

  Widget _buildGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 9 * 3,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 9,
          crossAxisSpacing: 4,
          mainAxisSpacing: 4,
          childAspectRatio: 0.4,
        ),
        itemBuilder: (context, index) {
          final row = index ~/ 9;
          final col = index % 9;
          return _buildCell(row,col);
        },
      )
    );
  }

  Widget _buildCell(int row, int col) {
    final cell = _grid[row][col];
    final bool isOpen = cell.open;
    final Color backColor = isOpen ? _themeColor.cardTableOpenBackColor : _themeColor.cardTableCloseBackColor;
    final Color textColor = isOpen ? _themeColor.cardTableOpenForeColor : _themeColor.cardTableCloseForeColor;
    final Color disableColor = _themeColor.cardTableDisableBackColor;
    final String label = cell.number.toString();
    Widget child;
    if (cell.number == 0) {
      child = Container(
        decoration: BoxDecoration(
          color: disableColor,
          borderRadius: BorderRadius.circular(8),
        ),
      );
    } else {
      child = AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: backColor,
          borderRadius: BorderRadius.circular(8),
          boxShadow: const [
            BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
          ],
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: Model.textSizeCard.toDouble(),
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      );
    }
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => _toggleCell(row, col),
      child: child,
    );
  }

  void _toggleCell(int row, int col) {
    HapticFeedback.selectionClick();
    setState(() {
      final cell = _grid[row][col];
      cell.open = !cell.open;
    });
    unawaited(_saveCardState());
  }

  Widget _buildFreeText() {
    return SizedBox(
      width: double.infinity,
      child: Column(children:[
        Card(
          margin: const EdgeInsets.only(left: 4, top: 32, right: 4, bottom: 0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(12),
              topRight: Radius.circular(12),
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          color: _themeColor.cardTableDisableBackColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _freeText1Controller,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      (value) => unawaited(Model.setFreeText1(value));
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Speak',
                  onPressed: _freeText1Controller.text.trim().isEmpty
                    ? null
                    : () => _speakText(_freeText1Controller.text),
                ),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(left: 4, top: 2, right: 4, bottom: 0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
              bottomLeft: Radius.circular(0),
              bottomRight: Radius.circular(0),
            ),
          ),
          color: _themeColor.cardTableDisableBackColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _freeText2Controller,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      (value) => unawaited(Model.setFreeText2(value));
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Speak',
                  onPressed: _freeText2Controller.text.trim().isEmpty
                    ? null
                    : () => _speakText(_freeText2Controller.text),
                ),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(left: 4, top: 2, right: 4, bottom: 0),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(0),
              topRight: Radius.circular(0),
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          color: _themeColor.cardTableDisableBackColor,
          elevation: 0,
          shadowColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _freeText3Controller,
                    textInputAction: TextInputAction.done,
                    onChanged: (value) {
                      (value) => unawaited(Model.setFreeText3(value));
                      setState(() {});
                    },
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.volume_up),
                  tooltip: 'Speak',
                  onPressed: _freeText3Controller.text.trim().isEmpty
                    ? null
                    : () => _speakText(_freeText3Controller.text),
                ),
              ],
            ),
          ),
        ),
      ])
    );
  }

  Future<void> _speakText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return;
    }
    try {
      await TextToSpeech.stop();
    } catch (_) {
      // Ignore stop errors.
    }
    await TextToSpeech.speak(trimmed);
  }

}

class _CardCell {
  _CardCell({required this.number});
  int number;
  bool open = false;
}
