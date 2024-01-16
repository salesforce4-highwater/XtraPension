trigger ApplicationTrigger on Application__c (after insert, after update) {
    ApplicationTriggerHandler handler = new ApplicationTriggerHandler(Trigger.newMap, Trigger.oldMap);
    switch on Trigger.operationType {
        when AFTER_UPDATE {
            handler.generatePdfFiles();
        }
        when AFTER_INSERT {
            handler.autopopulateRequiredFields();
        }
    }
}