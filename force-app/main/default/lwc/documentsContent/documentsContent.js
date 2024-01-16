import { LightningElement, api, track } from 'lwc';
import { NavigationMixin } from "lightning/navigation";
import getContentDocuments from '@salesforce/apex/DocumentsContentController.getContentDocuments';
import getAllDocuments from '@salesforce/apex/DocumentsContentController.getAllDocuments';
import changeCustomLetter from '@salesforce/apex/DocumentsContentController.changeCustomLetter';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import pdfAction from '@salesforce/apex/DocumentsContentController.pdfAction';

export default class DocumentsContent extends NavigationMixin(LightningElement) {
    @api recordId;
    @track latestDocs;
    @track allDocs;
    @track error;
    application;
    lastUKAddresses;
    previuosAddresses;
    lastUKEmployer;
    abroadEmployers;
    showAll = false;
    showLatest = true;
    isOpenModal = false;
    requestData;
    isShowSpinner = false;

    connectedCallback(){
        this.handleDocuments();
    }
    @api async handleDocuments() {
        await getContentDocuments({
            recordId : this.recordId
        })
        .then(result => {
          this.latestDocs        = result.latestDocs;
          this.allDocs           = result.latestDocs;
          this.application       = result.application;
          this.previuosAddresses = result.previousAddresses;
          this.lastUKEmployer    = result.lastUKEmployer;
          this.abroadEmployers   = result.abroadEmployers;
          this.lastUKAddresses   = result.latestUKAddress;
        }).catch(error => {
          this.error = error;
          console.log('error = ', this.error);
        });
    }
    navigateToFiles(event) {
        var documentName = event.currentTarget.getAttribute("value");
        var searchValue = this.allDocs.find(el => el.title == documentName);
        this[NavigationMixin.Navigate]({
          type: "standard__namedPage",
          attributes: {
            pageName: "filePreview",
          },
          state: {
            recordIds: searchValue.documentId
        },
      });
    }

    handleDisplayAll() {
      //this.handleAllDocuments();
      this[ NavigationMixin.Navigate ]( {
        type: 'standard__recordRelationshipPage',
        attributes: {
            recordId: this.recordId,
            objectApiName: 'Application__c',
            relationshipApiName: 'AttachedContentDocuments',
            actionName: 'view'
        }
    } );
    }
    @api async handleAllDocuments() {
      await getAllDocuments({
          recordId : this.recordId
      })
          .then(result => {
            this.allDocs    = result.allDocs;
          }).catch(error => {
              this.error = error;
              console.log('error = ', this.error);
      });
      this.showAll = !this.showAll;
      this.showLatest = !this.showLatest;
  }
    handleOpenModal() {
      this.isOpenModal = !this.isOpenModal;
  }
  closePopup() {
    this.isOpenModal = false;
  }
  @api get isApproved() {
    console.log('isApproved!');
    console.log('event.target!' );
    return true;
  }

  regenerateCustomLetter(event) {
    this.requestData = {
      applicationId    : this.recordId,
      freeformTextLine1: event.detail.freeformTextLine1,
      freeformTextLine2: event.detail.freeformTextLine2,
      freeformTextLine3: event.detail.freeformTextLine3,
      freeformTextLine4: event.detail.freeformTextLine4,
      newPreviousAddressData: event.detail.newPreviousAddressData,
      newEmployerData: event.detail.newEmployerCheckboxData
    }
    this.changeApplication();
  }
  changeApplication() {
    this.isShowSpinner = true;
    changeCustomLetter({
      letterData : JSON.parse(JSON.stringify(this.requestData))
    })
    .then(result => {
      if (result == 'true') {
        this.createNewContentDocument();
        const evt = new ShowToastEvent({
          title: 'Success',
          message: 'You have successfully changed the Custom Letter',
          variant: 'success'
        });
        this.dispatchEvent(evt);
        this.isShowSpinner = false;
      }
    }).catch(error => {
        this.dispatchEvent(new ShowToastEvent({
          title: 'Error',
          message: 'You didn\'t changed the Custom Letter. Error is: ' + error,
          variant: 'error',
      }));
      this.isShowSpinner = false;
      this.isOpenModal = false;
    });
  }
  createNewContentDocument() {
    pdfAction({
      applicationId : this.recordId
    }).then(result => {
      window.location.reload();
      console.log(result);
    }).catch(error => {
      console.log(error);
      this.isOpenModal = false;
    })
  }

  get colorValue() {
    let replyStatus = this.latestDocs.find( item => item.title == 'HMRC Assessment').hmrcReplyStatus;
    console.log('replyStatus === ', replyStatus);
    return replyStatus == 'APPROVED' ? 'color:green' :
              replyStatus == 'REJECT' ? 'color:red' :
                  replyStatus == 'UNKNOWN' ? 'color:blue' : null;
  }
}