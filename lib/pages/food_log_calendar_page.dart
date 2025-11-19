import 'package:flutter/material.dart';
import 'package:food_buyer_app/services/api_service.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class FoodLogCalendarPage extends StatefulWidget {
  const FoodLogCalendarPage({super.key});

  @override
  State<FoodLogCalendarPage> createState() => _FoodLogCalendarPageState();
}

class _FoodLogCalendarPageState extends State<FoodLogCalendarPage> {
  final ApiService _apiService = ApiService();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  List<dynamic> _allLogs = []; // [!] เก็บ Log ทั้งหมดที่โหลดมา
  List<dynamic> _logsForSelectedDay = []; // [!] Log ที่กรองแล้ว
  int _totalCaloriesForSelectedDay = 0;
  final int _recommendedCalories = 2000;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    _loadAllLogs(); // [!] โหลด Log ทั้งหมดครั้งเดียว
  }

  // [!] 1. โหลด Log ทั้งหมดจาก API
  Future<void> _loadAllLogs() async {
    final logs = await _apiService.getFoodLogs();
    setState(() {
      _allLogs = logs;
    });
    _filterLogsForDay(_selectedDay!); // [!] กรองสำหรับวันที่เลือก
  }

  // [!] 2. กรอง Log (ทำงานในแอป)
  void _filterLogsForDay(DateTime day) {
    final logs = _allLogs.where((log) {
      final eatenAt = DateTime.parse(log['eaten_at']);
      return isSameDay(eatenAt, day);
    }).toList();
    
    int totalCals = 0;
    for (final log in logs) totalCals += (log['calories'] as int);
    
    setState(() {
      _logsForSelectedDay = logs;
      _totalCaloriesForSelectedDay = totalCals;
    });
  }

  void _onDaySelected(DateTime selectedDay, DateTime focusedDay) {
    if (!isSameDay(_selectedDay, selectedDay)) {
      setState(() {
        _selectedDay = selectedDay;
        _focusedDay = focusedDay;
      });
      _filterLogsForDay(selectedDay); // [!] กรองใหม่
    }
  }

  String _translateMealTime(String time) {
    switch (time) {
      case 'breakfast': return 'เช้า';
      case 'lunch': return 'กลางวัน';
      case 'dinner': return 'เย็น';
      case 'snack': return 'ของว่าง';
      default: return time;
    }
  }

  // [!] UI เหมือนโค้ดต้นฉบับ
  @override
  Widget build(BuildContext context) {
    final int remainingCals = _recommendedCalories - _totalCaloriesForSelectedDay;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // --- 1. ปฏิทิน ---
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: _onDaySelected,
              calendarStyle: CalendarStyle(
                todayDecoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                selectedDecoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
              ),
              headerStyle: HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            SizedBox(height: 16),
            
            // --- 2. สรุปแคลอรี่ ---
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      '$_totalCaloriesForSelectedDay / $_recommendedCalories kcal',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      remainingCals >= 0 ? 'วันนี้ยังกินได้อีก $remainingCals kcal' : 'กินเกินไป ${remainingCals.abs()} kcal',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: (_totalCaloriesForSelectedDay / _recommendedCalories).clamp(0.0, 1.0),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 24),
            
            // --- 3. รายการที่กิน ---
            Text('เมนูที่กินในวันที่เลือก:', style: Theme.of(context).textTheme.titleMedium),
            if (_logsForSelectedDay.isEmpty)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text('ยังไม่มีการบันทึกในวันนี้'),
              ),
            ..._logsForSelectedDay.map((log) {
              return ListTile(
                leading: Icon(Icons.fastfood),
                title: Text(log['title']),
                subtitle: Text('มื้อ${_translateMealTime(log['meal_time'])} • ${log['calories']} kcal'),
                trailing: Text(DateFormat.Hm().format(DateTime.parse(log['eaten_at']))),
              );
            }),
          ],
        ),
      ),
    );
  }
}