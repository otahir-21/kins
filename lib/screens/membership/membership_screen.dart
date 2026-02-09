import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kins_app/core/utils/auth_utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:kins_app/core/constants/app_constants.dart';
import 'package:kins_app/providers/user_details_provider.dart';
import 'package:kins_app/widgets/floating_nav_overlay.dart';

/// Single membership screen: shows "Join Our Premium Community" (non-member)
/// or "Membership" details + Cancel/Renew + promo (member). Status from Firestore.
class MembershipScreen extends ConsumerStatefulWidget {
  const MembershipScreen({super.key});

  @override
  ConsumerState<MembershipScreen> createState() => _MembershipScreenState();
}

class _MembershipScreenState extends ConsumerState<MembershipScreen> {
  bool _isLoading = true;
  bool _isMember = false;
  String? _userName;
  String? _userEmail;
  String? _profilePhotoUrl;
  String _membershipId = '0000 0000 0000 0000';
  String _expiry = '05/27';
  String _accountType = 'Individual';

  @override
  void initState() {
    super.initState();
    _loadMembershipStatus();
  }

  Future<void> _loadMembershipStatus() async {
    final uid = currentUserId;
    if (uid == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      final expiry = data?['membershipExpiry'];
      final isActive = expiry is Timestamp && expiry.toDate().isAfter(DateTime.now());
      final userRepo = ref.read(userDetailsRepositoryProvider);
      final user = await userRepo.getUserDetails(uid);

      if (mounted) {
        setState(() {
          _isMember = isActive;
          _userName = user?.name ?? data?['name'] ?? 'Member';
          _userEmail = data?['email']?.toString();
          _profilePhotoUrl = user?.profilePictureUrl ?? data?['profilePictureUrl']?.toString();
          final rawId = (data?['membershipId'] ?? '0000000000000000').toString().replaceAll(' ', '');
          _membershipId = rawId.length >= 16
              ? '${rawId.substring(0, 4)} ${rawId.substring(4, 8)} ${rawId.substring(8, 12)} ${rawId.substring(12, 16)}'
              : rawId;
          if (expiry is Timestamp) {
            final d = expiry.toDate();
            _expiry = '${d.month.toString().padLeft(2, '0')}/${d.year.toString().substring(2)}';
          }
          _accountType = data?['membershipAccountType'] ?? 'Individual';
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() { _isMember = false; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(child: Center(child: CircularProgressIndicator(color: Color(0xFF6B4C93)))),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: FloatingNavOverlay(
        currentIndex: 3,
        child: SafeArea(
          child: _isMember ? _buildMemberView() : _buildNonMemberView(),
        ),
      ),
    );
  }

  Widget _buildNonMemberView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Text(
            'Join Our Premium Community',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.grey.shade900),
          ),
          const SizedBox(height: 12),
          Text(
            'Lorem Ipsum is simply dummy text of the printing and typesetting industry. Lorem Ipsum has been the industry\'s standard dummy text ever since the 1500s.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 24),
          _buildBecomeMemberCard(),
          const SizedBox(height: 20),
          _buildBenefitsList(),
          const SizedBox(height: 32),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Buy now – coming soon')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                elevation: 0,
                side: BorderSide(color: Colors.grey.shade300),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
              ),
              child: const Text('Buy now'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildBecomeMemberCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Become a Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('\$100 per year', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Color(0xFF6B4C93))),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFF6B4C93).withOpacity(0.2),
                  backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
                  child: _profilePhotoUrl == null ? Icon(Icons.person, color: Color(0xFF6B4C93)) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_userName ?? 'Member', style: const TextStyle(fontWeight: FontWeight.w600)),
                      if (_userEmail != null) Text(_userEmail!, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      Text('Membership ID: $_membershipId', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                      Text('Account type: $_accountType', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ],
                  ),
                ),
                Icon(Icons.verified, color: Color(0xFF6B4C93), size: 28),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    const benefits = [
      'Up to 2,000 AED of partner discounts',
      'View expert Q&As',
      'Basic chat messaging',
      'Access to exclusive events',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: benefits.map((b) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle, color: Color(0xFF6B4C93), size: 22),
            const SizedBox(width: 10),
            Expanded(child: Text(b, style: TextStyle(fontSize: 15, color: Colors.grey.shade800))),
          ],
        ),
      )).toList(),
    );
  }

  Widget _buildMemberView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: Color(0xFF6B4C93).withOpacity(0.2),
                      backgroundImage: _profilePhotoUrl != null ? NetworkImage(_profilePhotoUrl!) : null,
                      child: _profilePhotoUrl == null ? Icon(Icons.person, color: Color(0xFF6B4C93), size: 28) : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_userName ?? 'Member', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          if (_userEmail != null) Text(_userEmail!, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Membership ID: $_membershipId', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text('Expiry: $_expiry', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 4),
                Text('Account type: $_accountType', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                Align(alignment: Alignment.bottomRight, child: Text('kins', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF6B4C93)))),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cancel – coming soon'))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel', style: TextStyle(color: Colors.grey.shade700)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Renew – coming soon'))),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Renew', style: TextStyle(color: Colors.grey.shade700)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildPromoCard(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildPromoCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Container(
              height: 200,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Colors.blue.shade50, Colors.purple.shade50],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pool, size: 48, color: Colors.blue.shade300),
                    const SizedBox(height: 8),
                    Text('AURA SKYPOOL', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Color(0xFF6B4C93), borderRadius: BorderRadius.circular(8)),
                child: const Text('25% off', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12)),
              ),
            ),
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cancel anytime, no questions asked', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  Text('All plans include 7 days money back guarantee', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                  Text('Secure payment process', style: TextStyle(fontSize: 11, color: Colors.grey.shade700)),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              right: 0,
              left: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF6B4C93), shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Container(width: 6, height: 6, decoration: BoxDecoration(color: Colors.grey.shade400, shape: BoxShape.circle)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

}
