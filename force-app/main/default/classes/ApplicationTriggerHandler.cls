public class ApplicationTriggerHandler {
    public Map<Id, Application__c> newApplications;
    public Map<Id, Application__c> oldApplications;
    public final String APPROVE_EMAIL_TEMPLATE_NAME = 'HMRC Success Result Reply';
    private static final Map<String, String[]> PROJECT_NAME_BY_RELATED_PRODUCT_NAME = new Map<String, String[]>{
        'Freebie'  => new String[]{'Deposit (Free)', 'Application (Free)', 'Guidance on HMRC Reply (Free)'}
    };

    public ApplicationTriggerHandler(Map<Id, Application__c> newApplications, Map<Id, Application__c> oldApplications) {
        this.newApplications = newApplications;
        this.oldApplications = oldApplications;
    }

    public void generatePdfFiles () {
        Set<Id> updateSelfemployedAppIds = new Set<Id>();
        Set<Id> updateNameAppIds = new Set<Id>();
        Set<Id> updateEmailAppIds = new Set<Id>();

        for (Application__c app : newApplications.values()) {
            if (app.Status__c == 'Form Completed' && app.Status__c != oldApplications.get(app.Id).Status__c) {
                System.enqueueJob(new GeneratePDFCallout(app.Id));
                if (app.Is_Generate_Client_Summary_PDF__c == false) {
                    CustomSummerPdf.generateClientSummary(app.Id);
                }
            }
            if (app.Status__c == 'Printing House' && app.Status__c != oldApplications.get(app.Id).Status__c) {
                updateApplicationDocumentStatus(app.Id);
            }
            if (app.SelfEmployment_Employment_Abroad__c != oldApplications.get(app.Id).SelfEmployment_Employment_Abroad__c) {
                updateSelfemployedAppIds.add(app.Id);
            }
            if (!app.First_Name__c.equals(oldApplications.get(app.Id).First_Name__c) || !app.Second_Name__c.equals(oldApplications.get(app.Id).Second_Name__c)) {
                updateNameAppIds.add(app.Id);
            }
            if (app.Email__c != oldApplications.get(app.Id).Email__c) {
                updateEmailAppIds.add(app.Id);
            }
        }
        if (!updateSelfemployedAppIds.isEmpty()) {
            updateSelfemployedAbroadField(updateSelfemployedAppIds);
        }
        if (!updateNameAppIds.isEmpty()) {
            updateRelatedDocumentsAfterChangeApplicationName(updateNameAppIds);
        }
        if (!updateEmailAppIds.isEmpty()) {
            updateRelatedContactAfterChangeEmail(updateEmailAppIds);
        }
    }

    private void updateApplicationDocumentStatus(Id applicationId) {
        List<Application_Document__c> relatedAppDocs = [
            SELECT Status__c
            FROM Application_Document__c
            WHERE Application__c = :applicationId AND
                  File_Name__c LIKE '%ForSignature%'
            ORDER BY CreatedDate DESC
            LIMIT 10000
        ];
        if (relatedAppDocs.isEmpty()) return;
        Map<String, Application_Document__c> nameByApplicationDocument = new Map<String, Application_Document__c>();
        for (Application_Document__c appDoc : relatedAppDocs) {
            if (!nameByApplicationDocument.containsKey('CF083')) {
                nameByApplicationDocument.put('CF083', appDoc);
            } else if (!nameByApplicationDocument.containsKey('64-8')) {
                nameByApplicationDocument.put('64-8', appDoc);
            } else if (!nameByApplicationDocument.containsKey('CustomLetter')) {
                nameByApplicationDocument.put('CustomLetter', appDoc);
            } else if (!nameByApplicationDocument.containsKey('UPLOAD')) {
                nameByApplicationDocument.put('UPLOAD', appDoc);
            }
        }
        if(nameByApplicationDocument.isEmpty()) return;
        List<Application_Document__c> updateAppDocs = new List<Application_Document__c>();
        for (Application_Document__c doc: nameByApplicationDocument.values()) {
            doc.Status__c = 'Ready For PH';
            updateAppDocs.add(doc);
        }
        if (!updateAppDocs.isEmpty()) {
            update updateAppDocs;
        }
    }

    public void autoPopulateRequiredFields() {
        List<Application__c> updateApplications = new List<Application__c>();
        Map<String, Id> personEmailsByApplId = new Map<String, Id>();
        Map<String, Id> personPhonesByApplId = new Map<String, Id>();
        List<Agent__c> mainAgent = [
            SELECT
                Id,
                Name
            FROM Agent__c
        ];
        Id agentId = mainAgent.size() == 0 ? null : mainAgent[0].Id;
        for (Application__c app : newApplications.values()) {
            if (app.Package_Name__c == 'Freebie') {
                String randomValue = 'pi' + (Integer.valueOf(Math.Random() * 100000) + 10000000);
                updateApplications.add(new Application__c(
                    Id                            = app.Id,
                    Expiry_Date__c                = Datetime.now().addYears(1),
                    Stripe_Transaction_Id__c      = randomValue,
                    Personal_Details_Form_Link__c = 'https://go.xtrapension.com/form/' + randomValue,
                    Agent__c                      = mainAgent.size() == 0 ? null : mainAgent[0].Id
                ));
                personEmailsByApplId.put(app.Email__c, app.Id);
                personPhonesByApplId.put(app.Related_Contact_Phone__c, app.Id);
            }
        }
        if (updateApplications.isEmpty()) {
            return;
        }
        update updateApplications;
        Map<Id, Application__c> applications = new Map<Id, Application__c> ([
            SELECT Contact__c
            FROM Application__c
            WHERE Id IN :updateApplications
        ]);
        List<Account> newAccounts = new List<Account>();
        Map<Id, Account> appIdByRelatedAccount = new Map<Id, Account>();
        for (Application__c app : newApplications.values()) {
            if (app.Contact__c == null) {
                Account relatedAccount = new Account(
                    LastName                = app.First_Name__c + ' ' + app.Second_Name__c,
                    PersonEmail             = app.Email__c,
                    PersonMobilePhone       = app.Related_Contact_Phone__c
                );
                appIdByRelatedAccount.put(app.Id, relatedAccount);
                newAccounts.add(relatedAccount);
            }
        }
        Map<Id, Id> accountIdByContactId = new Map<Id, Id>();
        if (!newAccounts.isEmpty()) {
            insert newAccounts;
            Map<Id, Contact> currentContact = new Map<Id, Contact> ([
                SELECT
                    Id,
                    AccountId
                FROM Contact
                WHERE AccountId IN :newAccounts
            ]);
            for (Contact contact : currentContact.values()) {
                accountIdByContactId.put(contact.AccountId, contact.Id);
            }
        }
        if (!appIdByRelatedAccount.isEmpty()) {
            List<Application__c> applicationsWithNewContacts = new List<Application__c>();
            for (Id appId : appIdByRelatedAccount.keySet()) {
                Account account = appIdByRelatedAccount.get(appId);
                Application__c app = applications.get(appId);
                app.Contact__c = (String)accountIdByContactId.get(account.Id);
                app.Last_UK_Home_Address__CountryCode__s  = 'GB';
                applicationsWithNewContacts.add(app);
            }
            if (!applicationsWithNewContacts.isEmpty()) {
                update applicationsWithNewContacts;
            }
        }
    }

    private void updateSelfemployedAbroadField(Set<Id> updatedAppIds) {
        if (updatedAppIds.isEmpty()) {
            return;
        }
        List<Application__c> currentApplications = [
            SELECT
                Abroad_Employer_Address1__City__s,
                Abroad_Employer_Address1__CountryCode__s,
                Abroad_Employer_Address1__PostalCode__s,
                Abroad_Employer_Address1__StateCode__s,
                Abroad_Employer_Address1__Street__s,
                Abroad_Employer_End_Date1__c,
                Abroad_Employer_Name1__c,
                Abroad_Employer_Start_Date1__c,
                Abroad_Employer_Address1_State__c,
                Abroad_Employer_Address1_Country__c,
                Self_Employed_Start_Date1__c,
                Self_Employed_End_Date1__c,
                SelfEmployment_Employment_Abroad__c,
                (SELECT
                    Name,
                    Employers_Address__City__s,
                    Employers_Address__CountryCode__s,
                    Employers_Address__PostalCode__s,
                    Employers_Address__StateCode__s,
                    Employers_Address__Street__s,
                    Employers_Address_State__c,
                    Employers_Address_Country__c,
                    Employer_Name__c,
                    End_Date__c,
                    Start_Date__c,
                    Type_Of_After_UK_Employment__c
                FROM Employers__r
                WHERE Type__c = 'Work After UK'
                ORDER BY Name)
            FROM Application__c
            WHERE Id IN :updatedAppIds
        ];
        List<Application__c> updatedApps = new List<Application__c>();
        for (Application__c app : currentApplications) {
            if (app.SelfEmployment_Employment_Abroad__c == 'Employed') {
                for (Employer__c employer : app.Employers__r) {
                    if (employer.Type_Of_After_UK_Employment__c == 'Employed') {
                        app.Abroad_Employer_Address1__City__s        = employer.Employers_Address__City__s;
                        app.Abroad_Employer_Address1__CountryCode__s = employer.Employers_Address__CountryCode__s;
                        app.Abroad_Employer_Address1__PostalCode__s  = employer.Employers_Address__PostalCode__s;
                        app.Abroad_Employer_Address1__StateCode__s   = employer.Employers_Address__StateCode__s;
                        app.Abroad_Employer_Address1__Street__s      = employer.Employers_Address__Street__s;
                        app.Abroad_Employer_End_Date1__c             = employer.End_Date__c;
                        app.Abroad_Employer_Name1__c                 = employer.Employer_Name__c;
                        app.Abroad_Employer_Start_Date1__c           = employer.Start_Date__c;
                        app.Abroad_Employer_Address1_State__c        = employer.Employers_Address_State__c;
                        app.Abroad_Employer_Address1_Country__c      = employer.Employers_Address_Country__c;
                        app.Self_Employed_Start_Date1__c             = null;
                        app.Self_Employed_End_Date1__c               = null;
                        updatedApps.add(app);
                        break;
                    }
                }
            } else if (app.SelfEmployment_Employment_Abroad__c == 'Self-Employed') {
                for (Employer__c employer : app.Employers__r) {
                    if (employer.Type_Of_After_UK_Employment__c == 'Self-Employed') {
                        app.Abroad_Employer_Address1__City__s        = null;
                        app.Abroad_Employer_Address1__CountryCode__s = null;
                        app.Abroad_Employer_Address1__PostalCode__s  = null;
                        app.Abroad_Employer_Address1__StateCode__s   = null;
                        app.Abroad_Employer_Address1__Street__s      = null;
                        app.Abroad_Employer_End_Date1__c             = null;
                        app.Abroad_Employer_Name1__c                 = null;
                        app.Abroad_Employer_Start_Date1__c           = null;
                        app.Abroad_Employer_Address1_State__c        = null;
                        app.Abroad_Employer_Address1_Country__c      = null;
                        app.Self_Employed_Start_Date1__c             = employer.Start_Date__c;
                        app.Self_Employed_End_Date1__c               = employer.End_Date__c;
                        updatedApps.add(app);
                        break;
                    }
                }
            } else if (app.SelfEmployment_Employment_Abroad__c == 'Both') {
                Boolean isFoundEmployedEmployeer = false;
                Boolean isFoundSelfEmployedEmployeer = false;
                for (Employer__c employer : app.Employers__r) {
                    if (employer.Type_Of_After_UK_Employment__c == 'Self-Employed' && isFoundSelfEmployedEmployeer == false) {
                        app.Self_Employed_Start_Date1__c             = employer.Start_Date__c;
                        app.Self_Employed_End_Date1__c               = employer.End_Date__c;
                        isFoundSelfEmployedEmployeer = true;
                    }
                    if (employer.Type_Of_After_UK_Employment__c == 'Employed' && isFoundEmployedEmployeer == false) {
                        app.Abroad_Employer_Address1__City__s        = employer.Employers_Address__City__s;
                        app.Abroad_Employer_Address1__CountryCode__s = employer.Employers_Address__CountryCode__s;
                        app.Abroad_Employer_Address1__PostalCode__s  = employer.Employers_Address__PostalCode__s;
                        app.Abroad_Employer_Address1__StateCode__s   = employer.Employers_Address__StateCode__s;
                        app.Abroad_Employer_Address1__Street__s      = employer.Employers_Address__Street__s;
                        app.Abroad_Employer_End_Date1__c             = employer.End_Date__c;
                        app.Abroad_Employer_Name1__c                 = employer.Employer_Name__c;
                        app.Abroad_Employer_Start_Date1__c           = employer.Start_Date__c;
                        app.Abroad_Employer_Address1_State__c        = employer.Employers_Address_State__c;
                        app.Abroad_Employer_Address1_Country__c      = employer.Employers_Address_Country__c;
                        isFoundEmployedEmployeer = true;
                    }
                    if (isFoundEmployedEmployeer == true && isFoundSelfEmployedEmployeer == true) {
                        updatedApps.add(app);
                        break;
                    }
                }
            }
        }
        if (!updatedApps.isEmpty()) {
            update updatedApps;
        }
    }

    private void updateRelatedDocumentsAfterChangeApplicationName(Set<Id> currentAppIds) {
        List<ContentDocumentLink> relatedContentDocumentLinks = [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                LinkedEntityId
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :currentAppIds
        ];
        Map<Id, List<ContentDocumentLink>> appIdByRelatedContentDocumentLinks = new Map<Id, List<ContentDocumentLink>>();
        for (ContentDocumentLink link : relatedContentDocumentLinks) {
            List<ContentDocumentLink> relatedDocuments = appIdByRelatedContentDocumentLinks.get(link.LinkedEntityId);
            if(relatedDocuments == null) relatedDocuments = new List<ContentDocumentLink>();
            relatedDocuments.add(link);
            appIdByRelatedContentDocumentLinks.put(link.LinkedEntityId, relatedDocuments);
        }
        List<Application_Document__c> relatedApplicationDocuments = [
            SELECT
                Application__c,
                File_Name__c
            FROM Application_Document__c
            WHERE Application__c IN :currentAppIds
        ];
        Map<Id, List<Application_Document__c>> appIdByRelatedApplicationDocuments = new Map<Id, List<Application_Document__c>>();
        for (Application_Document__c document : relatedApplicationDocuments) {
            List<Application_Document__c> relatedDocuments = appIdByRelatedApplicationDocuments.get(document.Application__c);
            if(relatedDocuments == null) relatedDocuments = new List<Application_Document__c>();
            relatedDocuments.add(document);
            appIdByRelatedApplicationDocuments.put(document.Application__c, relatedDocuments);
        }
        List<SObject> updateDocuments = new List<SObject>();
        for (Id applicationId : appIdByRelatedContentDocumentLinks.keySet()) {
            String newName = newApplications.get(applicationId).First_Name__c + '_' + newApplications.get(applicationId).Second_Name__c;
            String oldName = oldApplications.get(applicationId).First_Name__c + '_' + oldApplications.get(applicationId).Second_Name__c;
            for (ContentDocumentLink link : appIdByRelatedContentDocumentLinks.get(applicationId)) {
                ContentDocument currentDocument = new ContentDocument();
                currentDocument.Id = link.ContentDocumentId;
                String title = link.ContentDocument.Title;
                currentDocument.Title = title.replace(oldName, newName);
                updateDocuments.add(currentDocument);
            }
        }
        for (Id applicationId : appIdByRelatedApplicationDocuments.keySet()) {
            String newName = newApplications.get(applicationId).First_Name__c + '_' + newApplications.get(applicationId).Second_Name__c;
            String oldName = oldApplications.get(applicationId).First_Name__c + '_' + oldApplications.get(applicationId).Second_Name__c;
            for (Application_Document__c document : appIdByRelatedApplicationDocuments.get(applicationId)) {
                Application_Document__c currentDocument = new Application_Document__c();
                currentDocument.Id = document.Id;
                String name = document.File_Name__c;
                currentDocument.File_Name__c = name.replace(oldName, newName);
                updateDocuments.add(currentDocument);
            }
        }
        if (!updateDocuments.isEmpty()) {
            update updateDocuments;
        }
    }

    private void updateRelatedContactAfterChangeEmail(Set<Id> updatesAppIds) {
        List<Contact> updateContacts = new List<Contact>();
        for (Id appId : updatesAppIds) {
            Application__c currentApp = newApplications.get(appId);
            Contact contact = new Contact();
            contact.Id = currentApp.Contact__c;
            contact.Email = currentApp.Email__c;
            updateContacts.add(contact);
        }
        if (!updateContacts.isEmpty()) {
            update updateContacts;
        }
    }
}