import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../state/language_state.dart';
import '../utils/constants.dart';
import '../utils/helpers.dart';
import '../widgets/summary_card.dart';
import '../widgets/transaction_tile.dart';
import '../widgets/add_transaction_sheet.dart';

class DashboardTab extends StatelessWidget {
  final AppState     appState;
  final String       username;
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
            SliverToBoxAdapter(child: _buildSummaryCards(context)),
            SliverToBoxAdapter(child: _buildActionButtons(context)),
            SliverToBoxAdapter(child: _buildRecentTitle(context)),
            _buildRecentList(context),
          ],
        ),
      ),
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

  // ── Header ──────────────────────────────────────────────────────
  Widget _buildHeader(BuildContext context) {
    final now    = DateTime.now();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final langState = Provider.of<LanguageState>(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${langState.t('hello')}, $username 👋', 
            style: TextStyle(color: isDark ? kTextSecondary : const Color(0xFF4A5568), fontSize: 14, fontWeight: FontWeight.w500)),
          Text(
            formatRelativeDate(now, langState),
            style: TextStyle(
              color: isDark ? kTextPrimary : const Color(0xFF1A202C), 
              fontSize: 24, 
              fontWeight: FontWeight.w900
            ),
          ),
        ],
      ),
    );
  }

  // ── Balance Card ────────────────────────────────────────────────
  Widget _buildBalanceCard(BuildContext context) {
    return ListenableBuilder(
      listenable: appState,
      builder: (context, _) {
        final balance = appState.totalBalance;
        final langState = Provider.of<LanguageState>(context);
        
        LinearGradient gradient;
        Color shadowColor;

        if (balance < 0) {
          gradient = const LinearGradient(
            colors: [Color(0xFFFF5252), Color(0xFFD32F2F)],
            begin: Alignment.topLeft, end: Alignment.bottomRight);
          shadowColor = Colors.red.withValues(alpha: 0.3);
        } else if (balance == 0) {
          gradient = const LinearGradient(
            colors: [Color(0xFF1E3A5F), Color(0xFF0D2137)],
            begin: Alignment.topLeft, end: Alignment.bottomRight);
          shadowColor = const Color(0xFF1E3A5F).withValues(alpha: 0.3);
        } else {
          gradient = const LinearGradient(
            colors: [Color(0xFF00C896), Color(0xFF00897B)],
            begin: Alignment.topLeft, end: Alignment.bottomRight);
          shadowColor = const Color(0xFF00C896).withValues(alpha: 0.3);
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              if (balance < 0) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFF5252), width: 2),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF5252), size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          langState.t('warning_negative'),
                          style: const TextStyle(color: Color(0xFFFF5252), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  gradient: gradient,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [BoxShadow(color: shadowColor, blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(langState.t('balance'), style: const TextStyle(color: Colors.white70, fontSize: 14)),
                    const SizedBox(height: 8),
                    if (!appState.isLoaded)
                      const Text('...', style: TextStyle(color: Colors.white70, fontSize: 32))
                    else
                      Text('฿${formatNum(balance)}',
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1)),
                    const SizedBox(height: 4),
                    Text(langState.t('baht'), style: const TextStyle(color: Colors.white60, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Summary Cards ─────────────────────────────────────────────────
  Widget _buildSummaryCards(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) => Row(
          children: [
            Expanded(
              child: SummaryCard(
                label: langState.t('income'),
                amount: appState.totalIncome,
                icon: Icons.arrow_downward_rounded,
                color: kAccentGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SummaryCard(
                label: langState.t('expense'),
                amount: appState.totalExpense,
                icon: Icons.arrow_upward_rounded,
                color: kAccentRed,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ──────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
      child: Row(
        children: [
          Expanded(
            child: _ActionButton(
              label: langState.t('add_income'),
              icon: Icons.add_rounded,
              color: kAccentGreen,
              onTap: () => showAddTransactionSheet(context, appState: appState, isIncome: true),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ActionButton(
              label: langState.t('add_expense'),
              icon: Icons.remove_rounded,
              color: kAccentRed,
              onTap: () => showAddTransactionSheet(context, appState: appState, isIncome: false),
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Transactions ─────────────────────────────────────────
  Widget _buildRecentTitle(BuildContext context) {
    final langState = Provider.of<LanguageState>(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
      child: Text(langState.t('recent'),
        style: const TextStyle(
          color: Color(0xFF1A202C), 
          fontSize: 18, 
          fontWeight: FontWeight.bold
        )),
    );
  }

  Widget _buildRecentList(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      sliver: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final recent = appState.transactions.take(5).toList();
          if (recent.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox());
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

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.8), color],
            begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))],
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
    );
  }
}
