global class XtraPensionEmailServiceHandler implements Messaging.InboundEmailHandler {
    global final String APPLICATION_ID_INDICATOR = 'AppID:';
    global final String TRACKING_NUMBER_INDICATOR = 'Tracking No:';
    global final String TRACKING_NUMBER_SEND_DATE_INDICATOR = 'Tracking No Rx\'d by Printer:';

    global Messaging.InboundEmailResult handleInboundEmail(Messaging.InboundEmail email, Messaging.InboundEnvelope envelope) {
        Messaging.InboundEmailResult result = new Messaging.InboundEmailresult();
        String plainText= '';
        plainText = email.plainTextBody;
        Task[] newTask = new Task[0];
        List<String> linesEmailBody = plainText.split('\n');
        String applicationName = '';
        String trackingNo = '';
        String trackingNoSendDate = '';
        for (Integer i = 0; i < linesEmailBody.size(); i++) {
            if (linesEmailBody[i].contains(APPLICATION_ID_INDICATOR)) {
                applicationName = linesEmailBody[i];
            }
            if (linesEmailBody[i].contains(TRACKING_NUMBER_INDICATOR)) {
                trackingNo = linesEmailBody[i];
            }
            if (linesEmailBody[i].contains(TRACKING_NUMBER_SEND_DATE_INDICATOR)) {
                trackingNoSendDate = linesEmailBody[i];
            }
        }
        if (String.isBlank(applicationName)) {
            result.message = 'This message doesn\'t contain application Id';
            result.success = false;
            return result;
        } else {
            applicationName    = applicationName.substringAfter(APPLICATION_ID_INDICATOR).trim().replaceAll('(\\s+)', '');
            trackingNo         = trackingNo.substringAfter(TRACKING_NUMBER_INDICATOR).trim();
            trackingNoSendDate = trackingNoSendDate.substringAfter(TRACKING_NUMBER_SEND_DATE_INDICATOR).trim();
        }
        try {
            List<Application__c> applications = [
                SELECT
                    Id,
                    Name
                FROM Application__c
                WHERE Name = :applicationName
            ];
            if (applications.isEmpty()) {
                result.message = 'Don\'t find application in SF';
                result.success = false;
                return result;
            }
            Application__c app = applications[0];
            List<SObject> upsertObjects = new List<SObject>();
            app.Tracking_Number__c = trackingNo;
            app.Tracking_Number_Received_Date__c = DateTime.now();
            app.Tracking_No_Rx_d_by_XP__c = trackingNoSendDate;
            app.Status__c = 'Posted';
            update app;
            EmailMessage emailMessage = new EmailMessage();
            emailMessage.status = '3';
            emailMessage.relatedToId = app.Id;
            emailMessage.fromAddress = email.fromAddress;
            emailMessage.fromName = email.fromName;
            emailMessage.Subject = email.subject;
            emailMessage.TextBody = plainText;
            upsertObjects.add(emailMessage);
            upsert upsertObjects;

        } catch (QueryException e) {
            System.debug('Query Issue: ' + e);
        }
        result.success = true;
        return result;
    }
}