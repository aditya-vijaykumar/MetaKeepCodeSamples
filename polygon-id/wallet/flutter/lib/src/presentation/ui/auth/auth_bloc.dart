import 'dart:typed_data';

import 'package:bloc/bloc.dart';
import 'dart:math';
import 'package:polygonid_flutter_sdk/common/domain/domain_constants.dart';
import 'package:polygonid_flutter_sdk/common/domain/domain_logger.dart';
import 'package:polygonid_flutter_sdk/common/domain/entities/chain_config_entity.dart';
import 'package:polygonid_flutter_sdk/common/domain/entities/env_entity.dart';
import 'package:polygonid_flutter_sdk/iden3comm/domain/entities/common/iden3_message_entity.dart';
import 'package:polygonid_flutter_sdk/iden3comm/domain/exceptions/iden3comm_exceptions.dart';
import 'package:polygonid_flutter_sdk/identity/domain/entities/identity_entity.dart';
import 'package:polygonid_flutter_sdk/sdk/polygon_id_sdk.dart';
import 'package:polygonid_flutter_sdk_example/src/data/secure_storage.dart';
import 'package:polygonid_flutter_sdk_example/src/presentation/dependency_injection/dependencies_provider.dart';
import 'package:polygonid_flutter_sdk_example/src/presentation/ui/auth/auth_event.dart';
import 'package:polygonid_flutter_sdk_example/src/presentation/ui/auth/auth_state.dart';
import 'package:polygonid_flutter_sdk_example/src/presentation/ui/common/widgets/profile_radio_button.dart';
import 'package:polygonid_flutter_sdk_example/utils/nonce_utils.dart';
import 'package:polygonid_flutter_sdk_example/utils/qr_code_parser_utils.dart';
import 'package:polygonid_flutter_sdk_example/utils/secure_storage_keys.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final PolygonIdSdk _polygonIdSdk;
  final QrcodeParserUtils _qrcodeParserUtils;

  static const SelectedProfile _defaultProfile = SelectedProfile.public;
  SelectedProfile selectedProfile = _defaultProfile;

  AuthBloc(
    this._polygonIdSdk,
    this._qrcodeParserUtils,
  ) : super(const AuthState.initial()) {
    on<ClickScanQrCodeEvent>(_handleClickScanQrCode);
    on<ScanQrCodeResponse>(_handleScanQrCodeResponse);
    on<ProfileSelectedEvent>(_handleProfileSelected);
  }

  void _handleProfileSelected(
      ProfileSelectedEvent event, Emitter<AuthState> emit) {
    selectedProfile = event.profile;
    emit(AuthState.profileSelected(event.profile));
  }

  ///
  Stream<String> get proofGenerationStepsStream =>
      _polygonIdSdk.proof.proofGenerationStepsStream();

  ///
  void _handleClickScanQrCode(
      ClickScanQrCodeEvent event, Emitter<AuthState> emit) {
    emit(const AuthState.navigateToQrCodeScanner());
  }

  ///
  Future<void> _handleScanQrCodeResponse(
      ScanQrCodeResponse event, Emitter<AuthState> emit) async {
    String? qrCodeResponse = event.response;
    if (qrCodeResponse == null || qrCodeResponse.isEmpty) {
      emit(const AuthState.error("no qr code scanned"));
      return;
    }

    try {
      final Iden3MessageEntity iden3message =
          await _qrcodeParserUtils.getIden3MessageFromQrCode(qrCodeResponse);
      emit(AuthState.loaded(iden3message));

      String? privateKey =
          await SecureStorage.read(key: SecureStorageKeys.privateKey);

      if (privateKey == null) {
        emit(const AuthState.error("no private key found"));
        return;
      }

      await _authenticate(
        iden3message: iden3message,
        privateKey: privateKey,
        emit: emit,
      );
    } catch (error) {
      emit(const AuthState.error("Scanned code is not valid"));
    }
  }

  ///
  Future<void> _authenticate({
    required Iden3MessageEntity iden3message,
    required String privateKey,
    required Emitter<AuthState> emit,
  }) async {
    emit(const AuthState.loading());

    final ChainConfigEntity currentChain =
        await _polygonIdSdk.getSelectedChain();
    final EnvEntity envEntity = await _polygonIdSdk.getEnv();

    String? did = await _polygonIdSdk.identity.getDidIdentifier(
      privateKey: privateKey,
      blockchain: currentChain.blockchain,
      network: currentChain.network,
    );

    IdentityEntity identityEntity = await _polygonIdSdk.identity.getIdentity(
      genesisDid: did,
      privateKey: privateKey,
    );

    try {
      final BigInt nonce = selectedProfile == SelectedProfile.public
          ? GENESIS_PROFILE_NONCE
          : await NonceUtils(getIt()).getPrivateProfileNonce(
              did: did, privateKey: privateKey, from: iden3message.from);

      // Migrate to authenticateV2 when MetaKeep support is added.
      await _polygonIdSdk.iden3comm.authenticate(
        message: iden3message,
        genesisDid: did,
        privateKey: privateKey,
        profileNonce: nonce,
      );

      emit(const AuthState.authenticated());
    } on OperatorException catch (error, stacktrace) {
      logger().e("Error: $error", error, stacktrace);
      emit(AuthState.error(error.errorMessage));
    } catch (error, stacktrace) {
      logger().e("Error: $error", error, stacktrace);
      emit(AuthState.error(error.toString()));
    }
  }
}