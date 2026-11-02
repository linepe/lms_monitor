import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    property alias cfg_lmsUrl: urlField.text
    property alias cfg_lmsApiKey: keyField.text
    property alias cfg_refreshInterval: intervalSpin.value

    Kirigami.FormLayout {
        QQC2.TextField {
            id: urlField
            Kirigami.FormData.label: i18n("Base URL:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            placeholderText: "http://127.0.0.1:1234"
        }
        QQC2.TextField {
            id: keyField
            Kirigami.FormData.label: i18n("API key:")
            Layout.preferredWidth: Kirigami.Units.gridUnit * 18
            echoMode: TextInput.Password
            placeholderText: i18n("Optional")
        }
        QQC2.SpinBox {
            id: intervalSpin
            Kirigami.FormData.label: i18n("Refresh every:")
            from: 5
            to: 3600
            textFromValue: function(v) { return i18n("%1 s", v) }
            valueFromText: function(t) { return parseInt(t) || 30 }
        }
    }
}
