import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/app_providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../widgets/primary_button.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final init = ref.watch(initProvider);

    ref.listen<InitState>(initProvider, (prev, next) {
      if (next.status == InitStatus.ready && next.modelsReady) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go('/');
        });
      }
    });

    if (init.status == InitStatus.ready && init.modelsReady && !init.onboardingComplete) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.go('/');
      });
    }

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 3),
              Text('Marginal', style: AppTextStyles.display(context)),
              const SizedBox(height: 12),
              Text(
                'Your notes. Your questions.\nNothing leaves this device.',
                style: AppTextStyles.h2(context).copyWith(
                  color: AppColors.plum,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(flex: 2),
              _buildFeatureRow(
                context,
                Icons.lock_outline_rounded,
                'Fully private',
                'Your documents and conversations never leave your phone. No cloud, no accounts, no tracking.',
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                context,
                Icons.chat_bubble_outline_rounded,
                'Chat with your notes',
                'Ask questions about your documents and get answers with direct citations back to the source.',
              ),
              const SizedBox(height: 20),
              _buildFeatureRow(
                context,
                Icons.phone_android_rounded,
                'Runs on your device',
                'A small AI model runs locally. Works offline once set up. Best on a phone from the last 3 years.',
              ),
              const Spacer(flex: 3),
              if (init.status == InitStatus.loading) ...[
                _buildDownloadProgress(context, init),
              ] else if (init.status == InitStatus.error) ...[
                Text(
                  'Error: ${init.error}',
                  style: AppTextStyles.caption(context).copyWith(
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 12),
                PrimaryButton(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onPressed: () => ref.read(initProvider.notifier).downloadModels(),
                ),
              ] else ...[
                PrimaryButton(
                  label: 'Download models & start',
                  icon: Icons.download_rounded,
                  onPressed: () => ref.read(initProvider.notifier).downloadModels(),
                ),
              ],
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Model download: ~400 MB total',
                  style: AppTextStyles.caption(context),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDownloadProgress(BuildContext context, InitState init) {
    final totalProgress = (init.modelProgress + init.embedderProgress) / 2;

    String phaseLabel;
    double phaseProgress;
    if (init.downloadPhase == 'generation') {
      phaseLabel = 'Downloading generation model';
      phaseProgress = init.modelProgress;
    } else if (init.downloadPhase == 'embedder') {
      phaseLabel = 'Downloading embedding model';
      phaseProgress = init.embedderProgress;
    } else {
      phaseLabel = 'Preparing...';
      phaseProgress = 0;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                value: totalProgress > 0 ? totalProgress : null,
                color: AppColors.plum,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$phaseLabel — ${(phaseProgress * 100).toInt()}%',
                style: AppTextStyles.bodyMedium(context),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalProgress > 0 ? totalProgress : null,
            minHeight: 6,
            backgroundColor: AppColors.border,
            color: AppColors.plum,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          totalProgress < 0.5
              ? 'First launch only — downloading to your device'
              : 'Almost ready...',
          style: AppTextStyles.caption(context),
        ),
      ],
    );
  }

  Widget _buildFeatureRow(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.plumSurface,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppColors.plum, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.bodySemiBold(context)),
              const SizedBox(height: 2),
              Text(description, style: AppTextStyles.caption(context)),
            ],
          ),
        ),
      ],
    );
  }
}
