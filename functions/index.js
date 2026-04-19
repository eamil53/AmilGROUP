const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

admin.initializeApp();

setGlobalOptions({ 
    region: 'us-central1',
    memory: '256MiB',
    timeoutSeconds: 30 
});

/**
 * 'notifications' koleksiyonuna yeni bir kayıt eklendiğinde tüm kullanıcılara push bildirimi gönderir.
 * Bu sayede toplu güncellemelerde (loop) birden fazla bildirim gitmesi engellenir.
 */
exports.sendpushnotification = onDocumentCreated('notifications/{docId}', async (event) => {
    const data = event.data.data();
    if (!data) return;

    const message = {
        notification: {
            title: data.title || 'Bilgilendirme',
            body: data.body || 'Bir güncelleme yapıldı.',
        },
        data: {
            senderId: data.senderId || '', // Gönderen bilgisini ekle
        },
        topic: 'targets',
        android: {
            priority: 'high',
            notification: {
                sound: 'default',
                channelId: 'general_channel'
            }
        },
        apns: {
            payload: {
                aps: {
                    sound: 'default'
                }
            }
        }
    };

    try {
        await admin.messaging().send(message);
        console.log('Push notification sent successfully:', data.title);
    } catch (error) {
        console.error('Error sending push notification:', error);
    }
});
