public class ManageMySubscriptions {
    
    public Contact con; 
    public Lead ld {get;set;}
    public Contact pageCon {get;set;}
    public Id subscriptionId {get;set;}
    public string groupName {get;set;}
    public map<Id, Subscription__c> subscrs {get;set;}
    public map<Id, Subscription_Membership__c> subscrItems {get;set;}
    
    public map<Id, memberWrp> subscrWrpItems {get;set;}
    public map<string, list<Subscription__c>> subscrsByGroup {get;set;}
    public map<string, string> groupNames {get;set;}
    public Boolean displayConfirmation {get;set;}
    
    //Created by Haaris 
    public Boolean hasSubsId {get;set;}
    public Boolean hasContactOrLeadId {get;set;}
    public Boolean hasEmailOptOut {get;set;}
    public string messageToDisplay {get;set;}
    public Boolean optOut {get;set;}
    public Map<String, String> unsubscribeReasons {get;set;}
    public Map<String, Boolean> showHideReasonMap{get;set;}
    public String showHideReasonString{get;set;}
    public String flagList{get;set;}
    public String grpName{get;set;}
    public String conId{get;set;}
    
    // unsubscription reasons
    public string unsubscribeReason {get;set;} //picklist response
    public string singleUnsubscribeReason {get;set;} //picklist response
    public map<string, string> unsubComments {get;set;}
    public string unsubscribeComments {get;set;} //text response
    
    // page params
    public string selectedGroup {get;set;}
        
    public ManageMySubscriptions() {
        
        ld = new Lead();
        con = new Contact();
        optOut = false;
        hasSubsId = false;
        hasContactOrLeadId = false;
        hasEmailOptOut = false;
        displayConfirmation = FALSE;
        messageToDisplay = '';
        showHideReasonMap = new Map<String, Boolean>();
        flagList = '';
        // retrieve subscription Id
        subscriptionId = ApexPages.currentPage().getParameters().get('sId');
        if (!string.isBlank(subscriptionId))
            hasSubsId = true;
        
        if (string.isBlank(ApexPages.currentPage().getParameters().get('cId')) && 
            string.isBlank(ApexPages.currentPage().getParameters().get('lId'))) 
        {
            displayConfirmation = TRUE;
            messageToDisplay = 'No Contact or Lead found.';
        } 
        else 
        {
            list<Contact> cons = new list<Contact>();
            list<Lead> leads = new list<Lead>();
            
            if (string.isNotBlank(ApexPages.currentPage().getParameters().get('cId'))) {
                //Get Contact
                string cId = ApexPages.currentPage().getParameters().get('cId');
                cons = [SELECT Id, FirstName, LastName, Email, Phone, DoNotCall, HasOptedOutOfEmail, hed_Do_Not_Contact__c, Needs_MC_Subscription_Update__c  FROM Contact WHERE Hash_Id__c = :cId OR Id = :cId];
                
            } 
            else if (string.isNotBlank(ApexPages.currentPage().getParameters().get('lId'))) {
                //Get Lead
                string lId = ApexPages.currentPage().getParameters().get('lId');
                leads = [SELECT Id, FirstName, LastName, Email, Phone, DoNotCall, HasOptedOutOfEmail, Do_Not_Contact__c, Needs_MC_Subscription_Update__c FROM Lead WHERE Hash_ID__c =:lId OR Id = :lId]; 
            }
            
            if (cons.size() > 0 || leads.size() > 0) {
                hasContactOrLeadId = true;
                if (cons.size() > 0) {
                    con = cons[0];
                    conId = con.Id;
                    pageCon = con.clone(false, true, false, false);
                    if(con.HasOptedOutOfEmail)
                        hasEmailOptOut = true;
                } 
                else if (leads.size() > 0) {
                    ld = leads[0];
                    if(ld.HasOptedOutOfEmail)
                        hasEmailOptOut = true;
                    pageCon = new Contact(FirstName = ld.FirstName, LastName = ld.LastName, Email = ld.Email, Phone = ld.Phone, HasOptedOutOfEmail = ld.HasOptedOutOfEmail, DoNotCall = ld.DoNotCall);
                }
                getSubscriptionsAndMemberships();
            } 
            else{
                displayConfirmation = TRUE;
                messageToDisplay = 'No Contact or Lead found.';
                return;
            }
        }
        if(subscriptionId != NULL)
            optOut = subscrWrpItems.get(subscriptionId).subscribed;
        setReasonMap();
    }
    
    public void setReasonMap(){
        String str = '{';
        //showHideReasonString
        Boolean flag;
        List<Subscription__c> subList;
        Integer len = 0;
        if (subscrsByGroup != null) {
            len = subscrsByGroup.size();
            Integer i = 1;
            for(String groupName : subscrsByGroup.keySet()){
                flag = true;
                subList = subscrsByGroup.get(groupName);
                for(Subscription__c eachSub : subList){
                    if(!subscrWrpItems.get(eachSub.Id).subscribed){
                        flag = false;
                        break;
                    }
                }
                if(i != len)
                    str += '\"'+groupName + '\":\"' + flag + '\",';
                else
                    str += '\"'+groupName + '\":\"' + flag + '\"}';
                i++;
                //showHideReasonMap.put(groupName, flag);
            }
        }
        showHideReasonString = str;
        System.debug('showHideReasonString '+showHideReasonString);
    }
    public void doGetReasonMap(){
        grpName = Apexpages.currentPage().getParameters().get('groupName');
        system.debug('groupName '+grpName);
        this.flagList = 'true';
        List<Subscription__c> subList;
        subList = subscrsByGroup.get(grpName);
        system.debug('subList '+subList);
        for(Subscription__c eachSub : subList){
            if(!subscrWrpItems.get(eachSub.Id).subscribed){
                this.flagList = 'false';
                break;
            }
        }
        grpName = 'reason' + grpName;
        system.debug('flagList '+flagList);
    }
    public list<SelectOption> getUnsubReasons() {
        list<SelectOption> options = new list<SelectOption>();
        Schema.DescribeFieldResult fieldResult = Subscription_Membership__c.Unsubscribed_Reason__c.getDescribe();
        List<Schema.PicklistEntry> ple = fieldResult.getPicklistValues();
        options.add(new SelectOption('Other', '-- Please Select --'));
        for (Schema.PicklistEntry f : ple) {
            options.add(new SelectOption(f.getLabel(), f.getValue()));
        }
        return options;
    }
    public String getTopMessage(){
        return 'Welcome to Pepperdine subscription center. On this page you can update your communication preferences. Note that if you unsubscribe from all you will be removed from all Pepperdine recruitment communications.';
    }
    public void getSubscriptionsAndMemberships() {
        groupName = '';
        subscrWrpItems = new map<Id, memberWrp>();
        unsubComments = new map<string, string>();
        unsubscribeReasons = new Map<String, String>();
        
        if (string.isNotBlank(ApexPages.currentPage().getParameters().get('group')))
            groupName = ApexPages.currentPage().getParameters().get('group');
                
        // retrieve all subscription memberships
        subscrItems = new Map<Id, Subscription_Membership__c>();
        if (!string.isBlank(con.Id)) {
            for (Subscription_Membership__c lm : [SELECT Id, Subscription__c, Subscription__r.Subscription_Id__c, 
                                                  Subscribed_Date__c, Subscription_Status__c, 
                                                  Unsubscribed_Comments__c, Unsubscribed_Date__c, 
                                                  Unsubscribed_Reason__c 
                                                  FROM Subscription_Membership__c 
                                                  WHERE Contact__c = :con.Id AND Subscription__r.Active__c = TRUE]) 
            {
                subscrItems.put(lm.Subscription__c, lm);
                subscrWrpItems.put(lm.Subscription__c, new memberWrp(lm));
            }
        } 
        else if (!string.isBlank(ld.Id)) {
            for (Subscription_Membership__c lm : [SELECT Id, Subscription__c, Subscription__r.Subscription_Id__c, 
                                                  Subscribed_Date__c, Subscription_Status__c, Unsubscribed_Comments__c,
                                                  Unsubscribed_Date__c, Unsubscribed_Reason__c 
                                                  FROM Subscription_Membership__c 
                                                  WHERE Lead__c = :ld.Id AND Subscription__r.Active__c = TRUE]) {
                subscrItems.put(lm.Subscription__c, lm);
                subscrWrpItems.put(lm.Subscription__c, new memberWrp(lm));
            }
        }
        
        //Get all subscription 
        list<Subscription__c> lsts = new list<Subscription__c>();
        if (string.isBlank(groupName)) {
            lsts = [SELECT Id, Public_Subscription_Label__c, Group_ID__c, Public_Group_Label__c, Description__c 
                    FROM Subscription__c WHERE Active__c = TRUE 
                    ORDER BY Public_Subscription_Label__c ASC];
        } 
        else {
            lsts = [SELECT Id, Public_Subscription_Label__c, Group_ID__c, Public_Group_Label__c, Description__c 
                    FROM Subscription__c WHERE Active__c = TRUE AND Group_ID__c = :groupName 
                    ORDER BY Public_Subscription_Label__c ASC];
        }
        
        // retrieve all subscriptions; if a subscription membership does not already exist, then create it.
        subscrs = new Map<Id, Subscription__c>();
        subscrsByGroup = new Map<String, list<Subscription__c>>();
        groupNames = new Map<String, String>();
        
        for (Subscription__c l : lsts) 
        {
            subscrs.put(l.Id, l);
            if (!subscrItems.containsKey(l.Id)) 
            {
                //This subscription do not have Subscription membership, so create a new one
                Subscription_Membership__c sm;
                if (con != null && con.Id != null) {
                    sm = new Subscription_Membership__c(Subscription__c = l.Id, 
                                                        Contact__c = con.Id, 
                                                        Subscription_Status__c = 'Subscribed');
                } 
                else if (ld != null && ld.Id != null) {
                    sm = new Subscription_Membership__c(Subscription__c = l.Id, 
                                                        Lead__c = ld.Id, 
                                                        Subscription_Status__c = 'Subscribed');
                }
                
                subscrItems.put(l.Id, sm);
                subscrWrpItems.put(sm.Subscription__c, new memberWrp(sm));
            }
            // organize subscriptions by group
            if (!subscrsByGroup.containsKey(l.Group_ID__c)) {
                subscrsByGroup.put(l.Group_ID__c, new list<Subscription__c>());
            }
            subscrsByGroup.get(l.Group_ID__c).add(l);
            
            if (!groupNames.containsKey(l.Group_ID__c)) 
            {
                groupNames.put(l.Group_ID__c, l.Public_Group_Label__c);
                unsubComments.put(l.Group_ID__c, '');
                unsubscribeReasons.put(l.Group_ID__c, '');
            }
        }
    }
    public pageReference updateSubscription() 
    {
        if (!string.isBlank(subscriptionId) && subscrItems != null && subscrItems.get(subscriptionId) != null) 
        {
            Subscription_Membership__c li = subscrItems.get(subscriptionId);
            boolean subscribed = optOut;
            system.debug('subscribed1 '+subscribed);
            if (subscribed) {
                li.Subscribed_Date__c = System.now();
                li.Subscription_Status__c = 'Subscribed';
                li.Unsubscribed_Date__c = null;
                li.Unsubscribed_Comments__c = '';
                li.Unsubscribed_Reason__c = '';
            } 
            else {
                li.Subscription_Status__c = 'Unsubscribed';
                li.Unsubscribed_Reason__c = singleUnsubscribeReason;
                li.Unsubscribed_Comments__c = unsubscribeComments;
                li.Unsubscribed_Date__c = System.now();
            }            
            upsert li;
        }
        displayConfirmation = TRUE;
        messageToDisplay = 'Your subscriptions have been updated.';
        return null;
    }
    public pageReference updateSubscriptionList() {        
        list<Subscription_Membership__c> lmsToUpsert = new list<Subscription_Membership__c>();
        if (subscrsByGroup.containsKey(selectedGroup)) {
            for (Subscription__c lst : subscrsByGroup.get(selectedGroup)) {
                Subscription_Membership__c li = subscrItems.get(lst.Id);
                boolean subscribed = subscrWrpItems.get(lst.Id).subscribed;
                if (subscribed) {
                    li.Subscribed_Date__c = System.now();
                    li.Subscription_Status__c = 'Subscribed';
                    li.Unsubscribed_Date__c = null;
                    li.Unsubscribed_Comments__c = '';
                    li.Unsubscribed_Reason__c = '';
                } 
                else {
                    li.Subscription_Status__c = 'Unsubscribed';
                    li.Unsubscribed_Reason__c = unsubscribeReasons.get(lst.Group_ID__c);
                    li.Unsubscribed_Comments__c = unsubComments.get(lst.Group_ID__c);
                    li.Unsubscribed_Date__c = System.now();
                }
                lmsToUpsert.add(li);
            }
        }        
        if (!lmsToUpsert.isEmpty()) 
            Database.upsert(lmsToUpsert);
        
        displayConfirmation = TRUE;
        messageToDisplay = 'Your subscriptions have been updated.';
        return null;
    }
    public pageReference globalUnsubscribe() {
        if (!string.isBlank(con.Id)) {
            //con.DoNotCall = TRUE;
            con.HasOptedOutOfEmail = TRUE;
            update con;
        } 
        else if (!string.isBlank(ld.Id)) {
            ld.HasOptedOutOfEmail = TRUE;
            //ld.DoNotCall = TRUE;
            update ld;
        }
        displayConfirmation = TRUE;
        hasEmailOptOut = TRUE;
        messageToDisplay = 'You have unsubscribed from all emails.';
        return null;
    }
    public pageReference globalSubscribe() {
        if (!string.isBlank(con.Id)) {
            //con.DoNotCall = TRUE;
            con.HasOptedOutOfEmail = FALSE;
            update con;
        } 
        else if (!string.isBlank(ld.Id)) {
            ld.HasOptedOutOfEmail = FALSE;
            //ld.DoNotCall = TRUE;
            update ld;
        }
        displayConfirmation = TRUE;
        hasEmailOptOut = FALSE;
        messageToDisplay = 'You have subscribed to all emails.';
        return null;
    }
    public class memberWrp {
        public Subscription_Membership__c sm {get;set;}
        public boolean subscribed {get;set;}
        
        public memberWrp(Subscription_Membership__c thisSM) {
            sm = thisSM;
            if (sm.Subscription_Status__c == 'Subscribed') 
                subscribed = true;
            else 
                subscribed = false;
        }   
    }
    public PageReference redirectPageOnReturn() {
        PageReference currentPage = ApexPages.currentPage();
        currentPage  =  new PageReference(currentPage.getURL());
        currentPage.getParameters().clear();
        if (con != null) currentPage.getParameters().put('cid', con.Id);
        if (ld != null) currentPage.getParameters().put('lid', ld.Id);
        currentPage.setRedirect(true);
        return currentPage;  
    }
    
}