import 'package:flutter/material.dart';
import 'package:payments_tracker_flutter/models/account_model.dart'; // Assuming AccountModel has 'name' and 'balance'
import 'package:payments_tracker_flutter/global_variables/app_colors.dart';
import 'package:payments_tracker_flutter/widgets/basic/basic_card.dart';
import 'package:payments_tracker_flutter/widgets/utility.dart';

class AccountCard extends StatelessWidget {
  final AccountModel account;
  final double balance;
  final VoidCallback onTap;
  final VoidCallback onEditPressed; // New callback for edit
  final VoidCallback onDeletePressed; // New callback for delete
  final bool isPinned;
  final VoidCallback onPinPressed;

  const AccountCard({
    super.key,
    required this.balance,
    required this.account,
    required this.onTap,
    required this.onEditPressed, // Make it required
    required this.onDeletePressed, // Make it required
    required this.isPinned,
    required this.onPinPressed,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 340;
        final avatarRadius = isCompact ? 20.0 : 24.0;
        final horizontalGap = isCompact ? 10.0 : 16.0;
        final cardPadding = isCompact ? 12.0 : 18.0;

        return BasicCard(
          margin: EdgeInsets.symmetric(
            horizontal: isCompact ? 12 : 20,
            vertical: 10,
          ),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: AppColors.subtlePurple.withValues(
                    alpha: 0.12,
                  ),
                  child: const Icon(Icons.person, color: AppColors.purple),
                ),
                SizedBox(width: horizontalGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Tooltip(
                        message: account.name,
                        child: SizedBox(
                          height: 52,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              account.name,
                              style: const TextStyle(
                                fontSize: 18,
                                height: 1.2,
                                fontWeight: FontWeight.bold,
                                color: AppColors.purple,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Utility.handleNumberAppearanceForOverflow(
                        number: balance,
                        color: balance >= 0
                            ? AppColors.greyishGreen
                            : AppColors.greyishRed,
                        fontSize: 11,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isCompact ? 4 : 8),
                IconButton(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 40,
                  ),
                  icon: Icon(
                    isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                    color: AppColors.purple,
                  ),
                  onPressed: onPinPressed,
                  tooltip: isPinned ? 'Unpin Account' : 'Pin Account',
                ),
                IconButton(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 40,
                  ),
                  icon: const Icon(Icons.edit, color: AppColors.purple),
                  onPressed: onEditPressed,
                  tooltip: 'Edit Account',
                ),
                IconButton(
                  constraints: const BoxConstraints(
                    minHeight: 40,
                    minWidth: 40,
                  ),
                  icon: const Icon(Icons.delete, color: AppColors.expenseRed),
                  onPressed: onDeletePressed,
                  tooltip: 'Delete Account',
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
