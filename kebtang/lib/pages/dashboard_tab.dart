import 'dart:convert' as convert;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import '../state/app_state.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/add_transaction_sheet.dart';

// ─── Dashboard Tab (หน้าสรุปผลหลัก) ────────────────────────────────

class DashboardTab extends StatelessWidget {
  final AppState appState;
  final String   username;
  final VoidCallback onLogout;

  const DashboardTab({
    super.key,
    required this.appState,
    required this.username,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () => appState.refreshData(),
        color: kAccentGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader(context)),
            SliverToBoxAdapter(child: _buildBalanceCard(context)),
            SliverToBoxAdapter(child: _buildBudgetCard(context)),
            SliverToBoxAdapter(child: _buildWeeklyChart(context)),
            SliverToBoxAdapter(child: _buildSummaryCards(context)),
            SliverToBoxAdapter(child: _buildActionButtons(context)),
            SliverToBoxAdapter(child: _buildRecentTitle(context)),
            _buildRecentList(context),
          ],
        ),
      ),
    );
  }

  // ── Weekly Chart ───────────────────────────────────────────────
  Widget _buildWeeklyChart(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final data = appState.weeklyExpenseData;
        final maxVal = data.isEmpty ? 0.0 : data.reduce((a, b) => a > b ? a : b);
        final langState = Provider.of<LanguageState>(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? kCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(langState.t('weekly_spending'), style: const TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.bold)),
                    const Icon(Icons.bar_chart_rounded, color: kAccentBlue, size: 18),
                  ],
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 120,
                  child: BarChart(
                    BarChartData(
                      gridData: const FlGridData(show: false),
                      titlesData: FlTitlesData(
                        show: true,
                        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            getTitlesWidget: (double val, TitleMeta meta) {
                              final now = DateTime.now();
                              final date = now.subtract(Duration(days: 6 - val.toInt()));
                              final days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
                              final dayKey = days[date.weekday % 7];
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(langState.t(dayKey), style: TextStyle(color: isDark ? kTextSecondary : Colors.grey[500], fontSize: 10)),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      barGroups: List.generate(7, (i) {
                        return BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(
                              toY: data[i] == 0 ? 0.5 : data[i],
                              color: data[i] == maxVal && maxVal > 0 ? kAccentRed : kAccentBlue.withValues(alpha: 0.6),
                              width: 14,
                              borderRadius: BorderRadius.circular(4),
                              backDrawRodData: BackgroundBarChartRodData(
                                show: true,
                                toY: maxVal == 0 ? 1 : maxVal,
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Budget Card ────────────────────────────────────────────────
  Widget _buildBudgetCard(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final budget = appState.budget;
        if (budget <= 0) return const SizedBox();

        final expense = appState.totalExpense;
        final progress = (expense / budget).clamp(0.0, 1.0);
        final isOver = expense > budget;
        final langState = Provider.of<LanguageState>(context);
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? kCard : Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: isDark ? [] : [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(langState.t('monthly_budget'), style: const TextStyle(color: kTextSecondary, fontSize: 13)),
                    Text(
                      '${(progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(color: isOver ? kAccentRed : kAccentBlue, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 10,
                    backgroundColor: isDark ? Colors.black26 : Colors.grey[200],
                    valueColor: AlwaysStoppedAnimation<Color>(isOver ? kAccentRed : kAccentBlue),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '฿${formatNum(expense)} / ฿${formatNum(budget)}',
                      style: TextStyle(color: isDark ? kTextPrimary : Colors.black87, fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                    if (isOver)
                      Text(
                        langState.t('over_budget'),
                        style: const TextStyle(color: kAccentRed, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Header Section ──────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return FutureBuilder<http.Response>(
      future: ApiConfig.getHeaders().then((h) => http.get(Uri.parse('${ApiConfig.baseUrl}/user/profile'), headers: h)),
      builder: (context, snapshot) {
        Color avatarColor = kAccentGreen;
        IconData avatarIcon = Icons.person_rounded;
        String dName = username;

        if (snapshot.hasData && snapshot.data!.statusCode == 200) {
          final data = convert.jsonDecode(snapshot.data!.body);
          if (data['avatarColor'] != null) avatarColor = Color(int.parse(data['avatarColor']));
          if (data['avatarIcon'] != null) avatarIcon = _getIconData(data['avatarIcon']);
          if (data['displayName'] != null && data['displayName'].toString().isNotEmpty) {
            dName = data['displayName'];
          }
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 30, 24, 20),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: avatarColor.withValues(alpha: 0.1),
                child: Icon(avatarIcon, color: avatarColor, size: 28),
              ),
              const SizedBox(width: 15),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(langState.t('hello'), style: const TextStyle(color: kTextSecondary, fontSize: 14)),
                  Text(dName, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                ],
              ),
              const Spacer(),
              IconButton(
                icon: Icon(Icons.notifications_none_rounded, color: isDark ? kTextSecondary : Colors.black45),
                onPressed: () {},
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getIconData(String name) {
    switch (name) {
      case 'face': return Icons.face_rounded;
      case 'pets': return Icons.pets_rounded;
      case 'star': return Icons.star_rounded;
      case 'favorite': return Icons.favorite_rounded;
      case 'bolt': return Icons.bolt_rounded;
      case 'rocket': return Icons.rocket_launch_rounded;
      case 'savings': return Icons.savings_rounded;
      case 'person':
      default: return Icons.person_rounded;
    }
  }

  // ─── Balance Card ────────────────────────────────────────────────

  Widget _buildBalanceCard(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final balance = appState.totalBalance;
          return Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3DA5D9), Color(0xFF2364AA)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(color: const Color(0xFF2364AA).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10))
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(langState.t('balance'), style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 10),
                Text('฿${formatNum(balance)}', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900, letterSpacing: -1)),
                if (balance < 0) ...[
                   const SizedBox(height: 12),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                     decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                     child: Text(langState.t('warning_negative'), style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                   ),
                ]
              ],
            ),
          );
        },
      ),
    );
  }

  // ─── Summary Small Cards ─────────────────────────────────────────

  Widget _buildSummaryCards(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          return Row(
            children: [
              _buildSummaryItem(context, langState.t('income'), appState.totalIncome, kAccentGreen, Icons.south_west_rounded),
              const SizedBox(width: 15),
              _buildSummaryItem(context, langState.t('expense'), appState.totalExpense, kAccentRed, Icons.north_east_rounded),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryItem(BuildContext context, String label, double amount, Color color, IconData icon) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? kCard : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: isDark ? [] : [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 14),
                ),
                const SizedBox(width: 8),
                Text(label, style: const TextStyle(color: kTextSecondary, fontSize: 12, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            FittedBox(
              child: Text('฿${formatNum(amount)}', style: TextStyle(color: isDark ? Colors.white : const Color(0xFF2D3748), fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Action Buttons ──────────────────────────────────────────────

  Widget _buildActionButtons(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      child: Row(
        children: [
          _buildCircleAction(context, Icons.add_rounded, kAccentGreen, langState.t('add_income'), true),
          const SizedBox(width: 15),
          _buildCircleAction(context, Icons.remove_rounded, kAccentRed, langState.t('add_expense'), false),
        ],
      ),
    );
  }

  Widget _buildCircleAction(BuildContext context, IconData icon, Color color, String label, bool isIncome) {
    return Expanded(
      child: InkWell(
        onTap: () => showAddTransactionSheet(context, isIncome: isIncome, appState: appState),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6))
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 22),
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Recent List ─────────────────────────────────────────────────

  Widget _buildRecentTitle(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 15),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(langState.t('recent'), style: TextStyle(color: isDark ? Colors.white : const Color(0xFF1A202C), fontSize: 18, fontWeight: FontWeight.bold)),
          Icon(Icons.history_rounded, color: isDark ? kTextSecondary : Colors.black26, size: 20),
        ],
      ),
    );
  }

  Widget _buildRecentList(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final recent = appState.transactions.take(5).toList();
          final langState = Provider.of<LanguageState>(context);
          final isDark = Theme.of(context).brightness == Brightness.dark;

          if (recent.isEmpty) {
            return SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 40),
                decoration: BoxDecoration(
                  color: isDark ? kCard.withValues(alpha: 0.5) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: isDark ? Colors.white10 : Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.auto_graph_rounded, size: 48, color: isDark ? kTextSecondary.withValues(alpha: 0.3) : Colors.grey[300]),
                    const SizedBox(height: 12),
                    Text(langState.t('no_data'), style: TextStyle(color: kTextSecondary.withValues(alpha: 0.6), fontSize: 14)),
                  ],
                ),
              ),
            );
          }
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, i) => TransactionTile(
                transaction: recent[i],
                appState: appState,
                showDivider: i < recent.length - 1,
              ),
              childCount: recent.length,
            ),
          );
        },
      ),
    );
  }
}
