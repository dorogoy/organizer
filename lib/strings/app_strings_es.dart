// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_strings.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppStringsEs extends AppStrings {
  AppStringsEs([String locale = 'es']) : super(locale);

  @override
  String get actionDone => 'Hecho';

  @override
  String get completionAcknowledgement => '¡Buen trabajo!';

  @override
  String get actionRescueOrSkip => 'Otra más fácil / Ahora no';

  @override
  String get pocketTrigger => 'Tengo 15 minutos ahora';

  @override
  String get sampleTask => 'Despeja la mesa del salón';

  @override
  String get destinationKeep => 'Quedármelo';

  @override
  String get destinationDonate => 'Donar o vender';

  @override
  String get destinationRelease => 'Tirar o soltar';

  @override
  String get liberatedVolume => '≈ 3 cajas liberadas';

  @override
  String get weeklySelfReportQuestion =>
      'Esta semana, ¿cuánto te ha agobiado la casa?';

  @override
  String get ambientInvitationStorage =>
      'Si no tienes nada que hacer, tengo un trabajillo para ti';

  @override
  String get ambientInvitationImprovement =>
      'Hay algo en la casa que se puede mejorar';

  @override
  String get ambientInvitationPocket => 'Con solo 15 minutos podemos avanzar';

  @override
  String get ambientInvitationTaskChange =>
      'Si necesitas cambiar de tarea, te puedo ayudar';

  @override
  String get ambientInvitationBreak =>
      'Te puedes tomar un respiro de 15 minutos haciendo otras cosas';

  @override
  String get checkpointStop => 'Nada más por el momento';

  @override
  String get checkpointContinue => 'Quiero seguir';

  @override
  String get warmReturnGreeting => 'Siempre a tu disposición';

  @override
  String get poolExhaustedClose =>
      'por hoy no hay nada más que merezca la pena';

  @override
  String get noSlicerNoKey =>
      'No hay clave de IA guardada. Crear un proyecto a partir de una foto necesita una; puedes añadirla en Ajustes.';

  @override
  String get noSlicerInvalidKey =>
      'La clave guardada no es válida. Puedes revisarla en Ajustes.';

  @override
  String get noSlicerQuotaExhausted =>
      'El crédito de la clave se ha agotado. Se repone en la cuenta del proveedor, no en la app.';

  @override
  String get noSlicerUnreachable =>
      'El servicio de IA no responde ahora mismo. Puedes intentarlo más tarde.';

  @override
  String get noSlicerOffline =>
      'El móvil está sin conexión. Los servicios que usan IA no son accesibles.';

  @override
  String get noSlicerConsentDeclined => 'La foto no se ha enviado.';

  @override
  String get personInFrame =>
      'Se ve una persona en la foto, así que no se ha enviado a ningún sitio. Puedes repetirla sin nadie en el encuadre.';

  @override
  String consentGateBody(String provider) {
    return 'La foto se procesará por $provider para obtener las tareas necesarias.';
  }

  @override
  String get consentGateSend => 'Enviar la foto';

  @override
  String get consentGateDecline => 'No enviarla';

  @override
  String get scanWaitTitle => 'Creando tareas';

  @override
  String get noSlicerExit => 'Anotarlo';

  @override
  String get newProjectLink => 'Nuevo proyecto';

  @override
  String get genesisAnalyze => 'Analizar';

  @override
  String get genesisBack => 'Volver';

  @override
  String get curationInvitation => 'Ajustar grupos de tareas';

  @override
  String get rewardWithoutPhoto => 'Un trabajo estupendo';

  @override
  String get rewardLabelBefore => 'Antes';

  @override
  String get rewardLabelAfter => 'Después';

  @override
  String get snowballDismissAcknowledgement => 'Está bien así.';

  @override
  String get energyCheckInQuestion => '¿Cuánta energía tienes hoy?';

  @override
  String get selfReportScaleLow => 'Nada';

  @override
  String get selfReportScaleHigh => 'Muchísimo';

  @override
  String get captureTitle => 'Un rincón de la casa';

  @override
  String get captureHelper =>
      'Una cosa que se pueda señalar con la mano: un cajón, una estantería, una silla, un rincón.';

  @override
  String get captureExample => 'Vaciar la caja de la entrada';

  @override
  String get captureFieldPlaceholder => 'Escríbelo o dilo en voz alta';

  @override
  String get dictationListening => 'Escuchando…';

  @override
  String get captureSave => 'Guardar';

  @override
  String get captureDiscard => 'Descartar';
}
