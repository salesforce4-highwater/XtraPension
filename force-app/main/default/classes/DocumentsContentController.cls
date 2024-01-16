public without sharing class DocumentsContentController {
    @AuraEnabled(cacheable='false')
    public static DocumentsData getContentDocuments(String recordId){
        List<ContentDocumentLink> forSignatureContentDocs = [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                LinkedEntityId,
                ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE
                LinkedEntityId = :recordId AND
                (ContentDocument.Title LIKE '%ForSignature%' OR
                ContentDocument.Title LIKE '%ClientSummary%')
            ORDER BY ContentDocument.CreatedDate DESC
        ];
        List<ContentDocumentLink> hmrcAssessmentContentDocs = [
            SELECT
                ContentDocumentId,
                ContentDocument.Title,
                LinkedEntityId,
                ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE
                LinkedEntityId = :recordId AND
                ContentDocument.Title LIKE '%HMRC Assessment%'
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];
        List<Application__c> currentApplication = [
            SELECT
                Name,
                Freeform_Text_Line1__c,
                Freeform_Text_Line2__c,
                Freeform_Text_Line3__c,
                Freeform_Text_Line4__c,
                Current_Address_Abroad__Street__s,
                Current_Address_Abroad__City__s,
                Current_Address_Abroad__CountryCode__s,
                Current_Address_Abroad__StateCode__s,
                Current_Address_Abroad__PostalCode__s,
                Docusigned_Date__c,
                National_Insurance_Number__c,
                Salutation__c,
                First_Name__c,
                Second_Name__c,
                Agent__r.First_Name__c,
                Agent__r.Last_Name__c,
                Last_UK_Home_Address__Street__s,
                Last_UK_Home_Address__City__s,
                Last_UK_Home_Address__CountryCode__s,
                Last_UK_Home_Address__PostalCode__s,
                Previous_UK_Address_1__Street__s,
                Previous_UK_Address_1__City__s,
                Previous_UK_Address_1__CountryCode__s,
                Previous_UK_Address_1__PostalCode__s,
                Include_UK_Address1__c,
                Previous_UK_Address_2__Street__s,
                Previous_UK_Address_2__City__s,
                Previous_UK_Address_2__CountryCode__s,
                Previous_UK_Address_2__PostalCode__s,
                Include_UK_Address2__c,
                Previous_UK_Address_3__Street__s,
                Previous_UK_Address_3__City__s,
                Previous_UK_Address_3__CountryCode__s,
                Previous_UK_Address_3__PostalCode__s,
                Include_UK_Address3__c,
                Previous_UK_Address_4__Street__s,
                Previous_UK_Address_4__City__s,
                Previous_UK_Address_4__CountryCode__s,
                Previous_UK_Address_4__PostalCode__s,
                Include_UK_Address4__c,
                Previous_UK_Address_5__Street__s,
                Previous_UK_Address_5__City__s,
                Previous_UK_Address_5__CountryCode__s,
                Previous_UK_Address_5__PostalCode__s,
                Include_UK_Address5__c,
                Last_UK_Employer_Name__c,
                Last_UK_Employer_Start_Date__c,
                Last_UK_Employer_End_Date__c,
                Last_UK_Employer_Address__City__s,
                Last_UK_Employer_Address__CountryCode__s,
                Last_UK_Employer_Address__StateCode__s,
                Last_UK_Employer_Address__Street__s,
                Last_UK_Employer_Address__PostalCode__s,
                Abroad_Employer_Name1__c,
                Abroad_Employer_Start_Date1__c,
                Abroad_Employer_End_Date1__c,
                Abroad_Employer_Address1__City__s,
                Abroad_Employer_Address1__CountryCode__s,
                Abroad_Employer_Address1__StateCode__s,
                Abroad_Employer_Address1__Street__s,
                Abroad_Employer_Address1__PostalCode__s,
                Career_Break_Employer_Name1__c,
                Career_Break_Employer_Start_Date1__c,
                Career_Break_Employer_End_Date1__c,
                Career_Break_Employer_Address1__City__s,
                Career_Break_Employer_Address1__CountryCode__s,
                Career_Break_Employer_Address1__StateCode__s,
                Career_Break_Employer_Address1__Street__s,
                Career_Break_Employer_Address1__PostalCode__s,
                Include_Abroad_Employer1__c,
                Include_Abroad_Employer2__c,
                Include_Abroad_Employer3__c,
                Include_Abroad_Employer4__c,
                Include_Abroad_Employer5__c,
                Include_Career_Break_Employer1__c,
                Include_Career_Break_Employer2__c,
                Include_Career_Break_Employer3__c,
                Include_Career_Break_Employer4__c,
                Include_Career_Break_Employer5__c,
                Current_Address_Abroad_State__c,
                Current_Address_Abroad_Country__c,
                Last_UK_Home_Address_Country__c,
                Previous_UK_Address_1_Country__c,
                Previous_UK_Address_2_Country__c,
                Previous_UK_Address_3_Country__c,
                Previous_UK_Address_4_Country__c,
                Previous_UK_Address_5_Country__c,
                Abroad_Employer_Address1_Country__c,
                Career_Break_Employer_Address1_Country__c,
                Last_UK_Employer_Address_Country__c,
                HMRC_Reply_Status__c,
                Is_Know_National_Insurance_Number__c,
                Previous_UK_Address_End_Date_1__c,
                Previous_UK_Address_End_Date_2__c,
                Previous_UK_Address_End_Date_3__c,
                Previous_UK_Address_Start_Date_1__c,
                Previous_UK_Address_Start_Date_2__c,
                Previous_UK_Address_Start_Date_3__c,
                    (SELECT
                        Employer_Name__c,
                        Start_Date__c,
                        End_Date__c,
                        Employers_Address__Street__s,
                        Employers_Address__City__s,
                        Employers_Address__CountryCode__s,
                        Employers_Address__StateCode__s,
                        Employers_Address__PostalCode__s,
                        Employers_Address_Country__c,
                        Type_Of_UK_Employment__c
                    FROM Employers__r
                    WHERE Type__c = 'UK Work')
            FROM Application__c
            WHERE Id = :recordId
        ];
        List<Employer__c> afterUKEmployers = [
			SELECT
				Employer_Name__c,
				Start_Date__c,
				End_Date__c,
				Employers_Address__Street__s,
				Employers_Address__City__s,
				Employers_Address__CountryCode__s,
				Employers_Address__StateCode__s,
				Employers_Address__PostalCode__s,
				Add_to_custom_letter__c,
				Employers_Address_Country__c,
                Type_Of_After_UK_Employment__c
			FROM Employer__c
			WHERE Application__c =: recordId
				AND Type__c = 'Work After UK'
			ORDER BY Start_Date__c ASC
		];
        if (forSignatureContentDocs.isEmpty() || currentApplication.isEmpty()) {
            return null;
        }
        List<dfsle__EnvelopeStatus__c> envelopStatus = [
            SELECT
                dfsle__Status__c,
                    (SELECT
                        Name
                    FROM DocuSign_Envelope_Documents__r)
            FROM dfsle__EnvelopeStatus__c
            WHERE Application__c = :recordId
            Order By CreatedDate DESC
        ];
        DocusingEnvelopeStatus statusWrapper = new DocusingEnvelopeStatus();
        if (!envelopStatus.isEmpty()) {
            for (dfsle__EnvelopeStatus__c status : envelopStatus) {
                for (dfsle__Document__c link : status.DocuSign_Envelope_Documents__r) {
                    if (link.Name.contains('CF083') && statusWrapper.cf083DocStatus == null) {
                        statusWrapper.cf083DocStatus = status.dfsle__Status__c;
                    }
                    if (link.Name.contains('64-8') && statusWrapper.agentDocStatus == null) {
                        statusWrapper.agentDocStatus = status.dfsle__Status__c;
                    }
                }
                if (statusWrapper.agentDocStatus != null && statusWrapper.cf083DocStatus != null) {
                    break;
                }
            }
        }
        DocumentsData data     = new DocumentsData();
        data.latestDocs        = new List<DocumentInfo>();
        data.previousAddresses = new List<PreviousUKAddressData>();
        data.abroadEmployers   = new List<EmployerData>();
        Map<String, DocumentInfo> titleByDocumentInfo = new Map<String, DocumentInfo>();
        Application__c app = currentApplication[0];
        List<String> notCompletedFiles = new List<String>();
        /*Map<String, ContentDocumentLink> titleByContentDocumentLink = new Map<String, ContentDocumentLink>();
        for (ContentDocumentLink link : forSignatureContentDocs) {
            String title = link.ContentDocument.Title;
            if (title.contains('completed')) {
                notCompletedFiles.add(title.substringBefore('_completed'));
            }
            titleByContentDocumentLink.put(title, link);
        }
        if (!notCompletedFiles.isEmpty()) {
            for (String name : notCompletedFiles) {
                if (titleByContentDocumentLink.get(name) != null) {
                    titleByContentDocumentLink.remove(name);
                }
            }
        }*/
        for (ContentDocumentLink link : forSignatureContentDocs) {
            String title = link.ContentDocument.Title;
            String docTitle = title.contains('64-8') ? 'Agent Authorisation':
                                title.contains('CF083') ? 'Application Form' :
                                    title.contains('CustomLetter') ? 'Custom Letter' :
                                        title.contains('UPLOAD') ? 'Client Uploaded Doc' :
                                            title.contains('ClientSummary') ? 'Client Summary' : null;
            if (titleByDocumentInfo.get(docTitle) != null) {
                continue;
            }
            DocumentInfo latestInfo = new DocumentInfo();
            latestInfo.title = docTitle;
            latestInfo.documentId  = link.ContentDocumentId;
            Datetime docCreatedDate = link.ContentDocument.CreatedDate;
            latestInfo.createdDate = docCreatedDate.format('EEE dd MMM yyyy');
            if (latestInfo.title == 'Custom Letter') {
                latestInfo.isCustomLetter = true;
            } else latestInfo.isCustomLetter = false;
            if (latestInfo.title == 'Application Form' && statusWrapper.cf083DocStatus != null) {
                latestInfo.isCompleteDocusignStatus = statusWrapper.cf083DocStatus == 'Completed' ? true : false;
                latestInfo.isApplicationForm        = true;
            }
            if (latestInfo.title == 'Agent Authorisation' && statusWrapper.agentDocStatus != null) {
                latestInfo.isCompleteDocusignStatus = statusWrapper.agentDocStatus == 'Completed' ? true : false;
                latestInfo.isAgentAuthorisation     = true;
            }
            titleByDocumentInfo.put(latestInfo.title, latestInfo);
        }
        if (!hmrcAssessmentContentDocs.isEmpty()) {
            DocumentInfo latestInfo = new DocumentInfo();
            latestInfo.title = 'HMRC Assessment';
            latestInfo.isHMRCReply = true;
            latestInfo.hmrcReplyStatus = app.HMRC_Reply_Status__c;
            latestInfo.documentId  = hmrcAssessmentContentDocs[0].ContentDocumentId;
            Datetime docCreatedDate = hmrcAssessmentContentDocs[0].ContentDocument.CreatedDate;
            latestInfo.createdDate = docCreatedDate.format('EEE dd MMM yyyy');
            titleByDocumentInfo.put(latestInfo.title, latestInfo);
        }
        if(titleByDocumentInfo.get('Custom Letter') != null) data.latestDocs.add(titleByDocumentInfo.get('Custom Letter'));
        if(titleByDocumentInfo.get('Application Form') != null) data.latestDocs.add(titleByDocumentInfo.get('Application Form'));
        if(titleByDocumentInfo.get('Agent Authorisation') != null) data.latestDocs.add(titleByDocumentInfo.get('Agent Authorisation'));
        if(titleByDocumentInfo.get('Client Uploaded Doc') != null) data.latestDocs.add(titleByDocumentInfo.get('Client Uploaded Doc'));
        if(titleByDocumentInfo.get('HMRC Assessment') != null) data.latestDocs.add(titleByDocumentInfo.get('HMRC Assessment'));
        if(titleByDocumentInfo.get('Client Summary') != null) data.latestDocs.add(titleByDocumentInfo.get('Client Summary'));

        data.application = app;
        PreviousUKAddressData latestAddress = new PreviousUKAddressData();
        latestAddress.addressData = app.Last_UK_Home_Address__Street__s + ', ' + app.Last_UK_Home_Address__City__s + ', ' +
                                    app.Last_UK_Home_Address__PostalCode__s + ', ' + app.Last_UK_Home_Address_Country__c;
        latestAddress.numberOfAddress =  1;
        data.latestUKAddress = latestAddress;
        for (Integer i = 1; i <= 5; i++) {
            if (app.get('Previous_UK_Address_' + i + '__Street__s') != null) {
                PreviousUKAddressData prevAddress = new PreviousUKAddressData();
                prevAddress.addressData =
                    app.get('Previous_UK_Address_' + i + '__Street__s') + ', ' +
                    app.get('Previous_UK_Address_' + i + '__City__s') + ', ' +
                    app.get('Previous_UK_Address_' + i + '__PostalCode__s') +  ', ' +
                    app.get('Previous_UK_Address_' + i + '_Country__c');
                prevAddress.checkboxFieldName = 'Include_UK_Address' + i +'__c';
                prevAddress.addToCustomLetter = (Boolean)app.get(prevAddress.checkboxFieldName);
                prevAddress.numberOfAddress = i + 1;
                data.previousAddresses.add(prevAddress);
            }
        }
        if (!afterUKEmployers.isEmpty()) {
            for (Integer i = 0; i < afterUKEmployers.size(); i++) {
                EmployerData abroadEmplolyer = new EmployerData();
                abroadEmplolyer.employerName = afterUKEmployers[i].Employer_Name__c;
                abroadEmplolyer.startDate = ((Datetime)afterUKEmployers[i].Start_Date__c).format('EEE dd MMM yyyy');
                abroadEmplolyer.endDate = ((Datetime)afterUKEmployers[i].End_Date__c).format('EEE dd MMM yyyy');
                if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Employed') {
                    abroadEmplolyer.isEmployedType = true;
                    abroadEmplolyer.employerType = 'Employed';
                    abroadEmplolyer.addressData = (String) afterUKEmployers[i].Employers_Address__Street__s  + ', ' +
                                                  ((String) afterUKEmployers[i].Employers_Address__City__s == null ? '' : (String) afterUKEmployers[i].Employers_Address__City__s + ', ' ) +
                                                  ((String) afterUKEmployers[i].Employers_Address__PostalCode__s == null ? '' : (String) afterUKEmployers[i].Employers_Address__PostalCode__s + ', ' ) +
                                                  (String) afterUKEmployers[i].Employers_Address_Country__c;
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Career Break') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Career Break';
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Self-Employed') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Self-Employed';
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Unemployed') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Unemployed';
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Family Carer') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Family Carer';
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Homemaker') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Homemaker';
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Disabled') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Disabled';
                } else if (afterUKEmployers[i].Type_Of_After_UK_Employment__c == 'Retired') {
                    abroadEmplolyer.isEmployedType = false;
                    abroadEmplolyer.employerType = 'Retired';
                }

                abroadEmplolyer.numberOfEmployer = i;
                abroadEmplolyer.employerId = afterUKEmployers[i].Id;
                String checkboxName = 'Include_Abroad_Employer' + i + '__c';
                abroadEmplolyer.checkboxFieldName = checkboxName;
                abroadEmplolyer.includeEmployer = afterUKEmployers[i].Add_to_custom_letter__c;
                data.abroadEmployers.add(abroadEmplolyer);
            }
        }

        EmployerData lastUKEmployer = new EmployerData();
        lastUKEmployer.employerName = app.Employers__r[0].Type_Of_UK_Employment__c == 'Employed' ?
                                        app.Employers__r[0].Employer_Name__c :
                                        app.Employers__r[0].Type_Of_UK_Employment__c;
        lastUKEmployer.startDate = app.Employers__r[0].Start_Date__c != null ?
                                        ((Datetime)app.Employers__r[0].Start_Date__c).format('EEE dd MMM yyyy') :
                                        null;
        lastUKEmployer.endDate   = app.Employers__r[0].End_Date__c != null ?
                                        ((Datetime)app.Employers__r[0].End_Date__c).format('EEE dd MMM yyyy') :
                                        null;
        lastUKEmployer.addressData = app.Employers__r[0].Type_Of_UK_Employment__c == 'Employed' ?
                                        app.Last_UK_Employer_Address__Street__s + ', ' +
                                        app.Last_UK_Employer_Address__City__s + ', ' +
                                        app.Last_UK_Employer_Address__PostalCode__s + ', ' +
                                        app.Last_UK_Employer_Address_Country__c :
                                        '';
        data.lastUKEmployer = lastUKEmployer;
        return data;
    }

    @AuraEnabled(cacheable='true')
    public static AllDocumentsData getAllDocuments(String recordId){
        List<ContentDocumentLink> contentDocs = [
        SELECT
            ContentDocumentId,
            ContentDocument.Title,
            LinkedEntityId,
            ContentDocument.CreatedDate
        FROM ContentDocumentLink
        WHERE LinkedEntityId = :recordId];
        if (contentDocs.isEmpty()) {
            return null;
        }
        AllDocumentsData data = new AllDocumentsData();
        data.allDocs = new List<DocumentInfo>();
        for (ContentDocumentLink link : contentDocs) {
            String title = link.ContentDocument.Title;
            if (title.contains('ForSignature')) {
                DocumentInfo docInfo = new DocumentInfo();
                docInfo.title      = title.contains('64-8') ? 'Agent Authorisation':
                                            title.contains('CF083') ? 'Application Form' :
                                                title.contains('CustomLetter') ? 'Custom Letter' :
                                                    title.contains('UPLOAD') ? 'Client Uploaded Doc' : null;
                docInfo.documentId  = link.ContentDocumentId;
                Datetime docCreatedDate = link.ContentDocument.CreatedDate;
                docInfo.createdDate = docCreatedDate.format('EEE dd MMM yyyy');
                if (docInfo.title == 'Custom Letter') {
                    docInfo.isCustomLetter = true;
                } else docInfo.isCustomLetter = false;
                data.allDocs.add(docInfo);
            } else {
                DocumentInfo docInfo = new DocumentInfo();
                docInfo.title       = title;
                docInfo.documentId  = link.ContentDocumentId;
                docInfo.createdDate = String.valueOf(link.ContentDocument.CreatedDate);
                data.allDocs.add(docInfo);
            }
        }
        return data;
    }

    @AuraEnabled
    public static String changeCustomLetter(CustomLetterData letterData) {
        try {
            Application__c updateApplication = new Application__c(
                Id = letterData?.applicationId,
                Freeform_Text_Line1__c = letterData?.freeformTextLine1,
                Freeform_Text_Line2__c = letterData?.freeformTextLine2,
                Freeform_Text_Line3__c = letterData?.freeformTextLine3,
                Freeform_Text_Line4__c = letterData?.freeformTextLine4
            );
            if (!letterData.newEmployerData.isEmpty()) {
                List<Id> changedEmployersIds = new List<Id>();
                for (ChangedDataWrapper wrapper : letterData?.newEmployerData) {
                    changedEmployersIds.add(wrapper?.employerId);
                }
                if (!changedEmployersIds.isEmpty()) {
                    Map<Id, Employer__c> changedEmployers = new Map<Id, Employer__c>([
                        SELECT Add_to_custom_letter__c
                        FROM Employer__c
                        WHERE Id IN :changedEmployersIds
                    ]);
                    for (ChangedDataWrapper wrapper : letterData?.newEmployerData) {
                        Employer__c currentEmployer = changedEmployers.get(wrapper?.employerId);
                        if (currentEmployer != null) {
                            currentEmployer.Add_to_custom_letter__c = Boolean.valueOf(wrapper?.value);
                        } else continue;
                    }
                    update changedEmployers.values();
                }
            }
            if (!letterData.newPreviousAddressData.isEmpty()) {
                for (ChangedDataWrapper wrapper : letterData?.newPreviousAddressData) {
                    updateApplication.put(wrapper?.fieldName, Boolean.valueOf(wrapper?.value));
                }

            }
            update updateApplication;
            return 'true';
        } catch (Exception ex) {
            return ex.getMessage();
        }
    }

    @AuraEnabled
    public static String pdfAction(String applicationId) {
        List<Application__c> currentApplication = [
            SELECT
                First_Name__c,
                Second_Name__c,
                Name,
                    (SELECT
                        ContentDocumentId,
                        ContentDocument.Title,
                        ContentDocument.CreatedDate,
                        LinkedEntityId
                    FROM ContentDocumentLinks
                    WHERE ContentDocument.Title LIKE '%CustomLetter%')
            FROM Application__c
            WHERE Id = :applicationId
        ];
        Application__c app = currentApplication[0];
        String forSignatureContDocument;
        if (app.ContentDocumentLinks.isEmpty()) {
            return 'Error';
        }
        for (ContentDocumentLink link : app.ContentDocumentLinks) {
            if (link.ContentDocument.Title.contains('ForSignature')) {
                forSignatureContDocument = link.ContentDocumentId;
                break;
            }
        }
        if (forSignatureContDocument != null) {
            List<ContentDocument> contentDocument = [
                SELECT
                    Id,
                    Title,
                    OwnerId
                FROM ContentDocument
                WHERE Id = :forSignatureContDocument
            ];
            ContentDocument currentDocument = contentDocument[0];
            Id currentUserId = UserInfo.getUserId();
            List<ContentDocumentLink> relatedLinks = [
                SELECT
                    LinkedEntityId
                FROM ContentDocumentLink
                WHERE
                    ContentDocumentId = :currentDocument.Id AND 
                    LinkedEntityId = :currentUserId
            ];
            if (relatedLinks.isEmpty() && currentUserId != currentDocument.OwnerId) {
                ContentDocumentLink currentUserContentDocumentLink = new ContentDocumentLink();
                currentUserContentDocumentLink.LinkedEntityId = currentUserId;
                currentUserContentDocumentLink.ContentDocumentId = currentDocument.Id;
                currentUserContentDocumentLink.shareType = 'V';
                currentUserContentDocumentLink.Visibility = 'AllUsers';
                insert currentUserContentDocumentLink;
            }
            if (!contentDocument.isEmpty()) {
                currentDocument.Title = currentDocument.Title.replace('ForSignature', 'v' + app.ContentDocumentLinks.size() + '.0');
                update contentDocument;
            }
        }
        PageReference savepage ;
        savepage = Page.CustomLetter;
        savepage.getParameters().put('id', applicationId);
        blob pdfBlob;
        if (!Test.isRunningTest()) {
            pdfBlob = savepage.getContent();
        } else {
            pdfBlob = Blob.valueOf('Test');
        }

        String FinalTitle = app.First_Name__c + '_' + app.Second_Name__c + '_' + app.Name +'_CustomLetter_ForSignature';

		ContentVersion conVer = new ContentVersion();
		conVer.ContentLocation = 'S';
		conVer.PathOnClient = FinalTitle+'.pdf';
		conVer.Title = FinalTitle;
		conVer.VersionData = pdfBlob;
		system.debug('conVer@@ ' + conVer);
		insert conVer;

		ContentVersion conDoc = [SELECT ContentDocumentId, ContentSize FROM ContentVersion WHERE Id =:conVer.Id][0];

		ContentDocumentLink conDocLink = New ContentDocumentLink();
		conDocLink.LinkedEntityId = applicationId;
		conDocLink.ContentDocumentId = conDoc.ContentDocumentId;
		conDocLink.shareType = 'V';
        conDocLink.Visibility = 'AllUsers';
		insert conDocLink;

        List<Application_Document__c> relatedAppDocs = [
            SELECT Id
            FROM Application_Document__c
            WHERE Application__c = :app.Id AND
                  File_Name__c LIKE '%CustomLetter%'
        ];
        if (relatedAppDocs.isEmpty()) {
            return 'Error';
        }
        insert new ContentDocumentLink(
            ContentDocumentId = conDoc.ContentDocumentId,
            LinkedEntityId    = relatedAppDocs[0].Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        return 'Success';
    }

    public class DocumentsData {
        @AuraEnabled
        public List<DocumentInfo> latestDocs{get; set;}
        @AuraEnabled
        public Application__c application{get; set;}
        @AuraEnabled
        public PreviousUKAddressData latestUKAddress{get; set;}
        @AuraEnabled
        public List<PreviousUKAddressData> previousAddresses{get; set;}
        @AuraEnabled
        public EmployerData lastUKEmployer{get; set;}
        @AuraEnabled
        public List<EmployerData> abroadEmployers{get; set;}
    }

    public class EmployerData {
        @AuraEnabled
        public String startDate{get; set;}
        @AuraEnabled
        public String endDate{get; set;}
        @AuraEnabled
        public String employerName{get; set;}
        @AuraEnabled
        public String addressData {get; set;}
        @AuraEnabled
        public Integer numberOfEmployer {get; set;}
        @AuraEnabled
        public Boolean includeEmployer {get; set;}
        @AuraEnabled
        public String checkboxFieldName{get; set;}
        @AuraEnabled
        public String employerId{get; set;}
        @AuraEnabled
        public Boolean isEmployedType{get; set;}
        @AuraEnabled
        public String employerType{get; set;}
    }

    public class PreviousUKAddressData {
        @AuraEnabled
        public String addressData{get; set;}
        @AuraEnabled
        public Boolean addToCustomLetter{get; set;}
        @AuraEnabled
        public Integer numberOfAddress{get; set;}
        @AuraEnabled
        public String checkboxFieldName{get; set;}
    }

    public class AllDocumentsData {
        @AuraEnabled
        public List<DocumentInfo> allDocs{get; set;}
    }

    public class DocumentInfo {
        @AuraEnabled
        public String title;
        @AuraEnabled
        public String documentId;
        @AuraEnabled
        public String createdDate;
        @AuraEnabled
        public Boolean isCustomLetter;
        @AuraEnabled
        public Boolean isHMRCReply;
        @AuraEnabled
        public Boolean isApplicationForm = false;
        @AuraEnabled
        public Boolean isAgentAuthorisation = false;
        @AuraEnabled
        public String hmrcReplyStatus;
        @AuraEnabled
        public Boolean isCompleteDocusignStatus = false;
    }

    public class CustomLetterData {
        @AuraEnabled
        public String applicationId{get; set;}
        @AuraEnabled
        public String freeformTextLine1{get; set;}
        @AuraEnabled
        public String freeformTextLine2{get; set;}
        @AuraEnabled
        public String freeformTextLine3{get; set;}
        @AuraEnabled
        public String freeformTextLine4{get; set;}
        @AuraEnabled
        public String freeformTextLine5{get; set;}
        @AuraEnabled
        public List<ChangedDataWrapper> newPreviousAddressData{get; set;}
        @AuraEnabled
        public List<ChangedDataWrapper> newEmployerData{get; set;}
    }

    public class ChangedDataWrapper {
        @AuraEnabled
        public String fieldName{get; set;}
        @AuraEnabled
        public String value{get; set;}
        @AuraEnabled
        public String employerId{get; set;}
    }

    public class DocusingEnvelopeStatus {
        public String cf083DocStatus;
        public String agentDocStatus;
    }
}