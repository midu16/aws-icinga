# -*- coding: utf-8 -*-
import re
from FIO.IcingaAlarmProperty import IcingaAlarmProperty


class IcingaAlarm():
    def __init__(self):
        self._duplicateClearAttributes = None
        self._lookup_severity = {
            '0': [re.compile('Normal', re.IGNORECASE), re.compile('OK', re.IGNORECASE), re.compile('0')],
            '2': [re.compile('Warning', re.IGNORECASE),  re.compile('2')],
            '3': [re.compile('Minor', re.IGNORECASE), re.compile('3')],
            '4': [re.compile('Major', re.IGNORECASE), re.compile('4')],
            '5': [re.compile('Critical', re.IGNORECASE), re.compile('5')],
        }
        self._reverse_lookup_severity = {
            'Ok': re.compile('0'),
            'Warning': re.compile('2'),
            'Minor': re.compile('3'),
            'Major': re.compile('4'),
            'Critical': re.compile('5'),
        }
        self._lookup_Type = {
            '14': [re.compile('NAA', re.IGNORECASE), re.compile('NAC', re.IGNORECASE), re.compile('14')],
            '13': [re.compile('Information', re.IGNORECASE), re.compile('13')],
            '1': [re.compile('Problem', re.IGNORECASE), re.compile('1')],
            '2': [re.compile('Resolution', re.IGNORECASE), re.compile('2')],
        }

        self._AlarmProperties = []
        self._AlertGroup = IcingaAlarmProperty("AlertGroup", "ag", ".*", 255)
        self._AlertKey = IcingaAlarmProperty("AlertKey", "ak", ".*", 255, "")
        self._ARSGroup = IcingaAlarmProperty("ARSGroup", "asg", ".*", 255)
        self._ARSNotes = IcingaAlarmProperty("ARSNotes", "asn", ".*", 1024)
        self._ARSOpCat1 = IcingaAlarmProperty("ARSOpCat1", "as1", ".*", 64)
        self._ARSOpCat2 = IcingaAlarmProperty("ARSOpCat2", "as2", ".*", 64)
        self._ARSOpCat3 = IcingaAlarmProperty("ARSOpCat3", "as3", ".*", 64)
        self._ARSSubmitter = IcingaAlarmProperty("ARSSubmitter", "ass", "\\S+", 64)
        self._ARSUrgency = IcingaAlarmProperty("ARSUrgency", "asu", "1000|2000|3000|4000", 4)
        self._CIId = IcingaAlarmProperty("CIId", "ci", "\\S+", 128)
        self._Class = IcingaAlarmProperty("Class", "cl", "\\d+", 8)
        self._Delay = IcingaAlarmProperty("Delay", "dy", "\\d+", 8)
        self._MsgGroup = IcingaAlarmProperty("MsgGroup", "mg", "\\S+", 64)
        self._NEFirstOccurrence = IcingaAlarmProperty("NEFirstOccurrence", "nfo", "\\d+", 64)
        self._Node = IcingaAlarmProperty("Node", "n", "\\S+", 128)
        self._OnCall = IcingaAlarmProperty("OnCall", "oc", "\\S+", 32)
        self._Poll = IcingaAlarmProperty("Poll", "po", "\\d+", 32)
        self._ProcessReq = IcingaAlarmProperty("ProcessReq", "pr", "\\d+", 4)
        self._Severity = IcingaAlarmProperty("Severity", "Sev", "0|Normal|OK|2|Warning|3|Minor|4|Major|5|Critical", 10)
        self._Summary = IcingaAlarmProperty("Summary", "sum", ".*", 1024)
        self._SuppressEscl = IcingaAlarmProperty("SuppressEscl", "se", "0|20|23", 4)
        self._ServiceId = IcingaAlarmProperty("ServiceId", "si", "\\S+", 128)
        self._NEIPAddress = IcingaAlarmProperty("NEIPAddress", "ne", "\\d+\\.\\d+\\.\\d+\\.\\d+", 15)
        self._Technology = IcingaAlarmProperty("Technology", "te", "\\S+", 32)
        self._Type = IcingaAlarmProperty("Type", "tp", "14|NAA|NAC|1|Problem|2|Resolution|13|Information", 15)
        self._Version = IcingaAlarmProperty("version", "v", "2", 15)
        self._URL = IcingaAlarmProperty("URL", "URL", ".*", 1024)
        self._EMSAlarmId = IcingaAlarmProperty("EMSAlarmId", "aid", ".*", 64)
        self._EquipmentType = IcingaAlarmProperty("EquipmentType", "eqt", ".*", 50)
        self._EventId = IcingaAlarmProperty("EventId", "eid", ".*", 255)
        self._ExpireTime = IcingaAlarmProperty("ExpireTime", "et", "\\d+", 255)
        #  Todo Key Value pair check e.g key=value; [key=value];
        self._ExtendedAttr = IcingaAlarmProperty("ExtendedAttr", "ea", ".*", 4096)
        # Finish Todo
        self._HelpKey = IcingaAlarmProperty("HelpKey", "hk", ".*", 256)
        self._Location = IcingaAlarmProperty("Location", "lo", ".*", 64)
        ## Properties which are not send to UMS
        self._SMS = IcingaAlarmProperty("SMS", "sms", ".*", 1024)
        self._Email = IcingaAlarmProperty("Email", "em", ".*", 1024)
        self._ForceResend = IcingaAlarmProperty("ForceResend", "fr", "1|true", 5)
        self._ValueChangedEvent = IcingaAlarmProperty("ValueChangedEvent", "vce", ".*", 1024)
        ## Properties used for Icinga Reporting
        self._Report = IcingaAlarmProperty("Report", "rep", ".*", 1024)
        self._AlarmProperties = [self._AlertGroup, self._AlertKey, self._ARSGroup, self._ARSNotes, self._ARSOpCat1,
                                 self._ARSOpCat2, self._ARSOpCat3, self._ARSSubmitter, self._ARSUrgency, self._CIId,
                                 self._Class, self._Delay, self._MsgGroup, self._NEFirstOccurrence, self._Node,
                                 self._OnCall, self._Poll, self._ProcessReq, self._Severity, self._Summary,
                                 self._SuppressEscl, self._ServiceId, self._NEIPAddress, self._Technology, self._Type,
                                 self._Version, self._URL, self._EMSAlarmId, self._EquipmentType, self._EventId,
                                 self._ExpireTime, self._ExtendedAttr, self._HelpKey, self._Location, self._SMS,
                                 self._Email, self._ForceResend, self._ValueChangedEvent, self._Report]
        self._AlarmKeyProperties = [self._Summary, self._Severity, self._MsgGroup, self._AlertGroup]

    def __str__(self):
        output = ''
        summaray = ''
        #x=mySeperator.join(self._AlarmProperties)
        for i in self._AlarmProperties:
            if i.matchedKey('Summary'):
                summaray=f'{self._longSeverity()} - {self._dequote(i.getValue())}'
                #summaray.startswith(("'", '"')):
            else:
                if i.hasValue():
                    output = output + ' ' + i.getIcingaFormatShortNameProp()
        return f'{summaray}  [{self._MsgGroup.getValue()},{self._AlertGroup.getValue()}] <!-- {output} -->'

    def __eq__(self, other):
        return self._AlertGroup.getValue() == other._AlertGroup.getValue() and self._AlertKey.getValue() == other._AlertKey.getValue()

    def __lt__(self, other):
        return self.getSeverity() > other.getSeverity()

    def getDuplicateClearAttributes(self):
        alertGroup=None
        alertKey=None
        for i in self._AlarmProperties:
            if i.matchedKey('AlertGroup'):
                alertGroup=i.getValue()
            if i.matchedKey('AlertKey'):
                alertKey=i.getValue()
                #print(alertKey)
        self._duplicateClearAttributes = f'AlertGroup={alertGroup} AlertKey={alertKey}'
        #print(self._duplicateClearAttributes)
        return f'AlertGroup={alertGroup} AlertKey={alertKey}'

    def checkDuplicates(self, value):
        #print(f'{self.getDuplicateClearAttributes()} == {value}')
        if self.getDuplicateClearAttributes() == value:
            return True
        return False

    def setSummary(self, summary):
        """Important Alarm Property for Netcool Clearing"""
        self._Summary.setValue(summary)

    def setAlertGroup(self, alertgroup):
        """Important Alarm Property for Netcool Clearing"""
        self._AlertGroup.setValue(alertgroup)
        self._duplicateClearAttributes=f'AlertGroup={self._AlertGroup} AlertKey={self._AlertKey}'

    def setAlertKey(self, alertkey):
        """Important Alarm Property for Netcool Clearing"""
        self._AlertKey.setValue(alertkey)
        self._duplicateClearAttributes = f'AlertGroup={self._AlertGroup} AlertKey={self._AlertKey}'

    def setMsgGroup(self, msggroup):
        """Important Alarm Property for Netcool """
        self._MsgGroup.setValue(msggroup)

    #def setType(self, type):
     #   """Important Alarm Property for Netcool """
     #   self.setType(type)
    #    #self._Type.setValue(type)

    def setCritical(self):
        self._Severity.setValue("Critical")

    def setMajor(self):
        self._Severity.setValue("Major")

    def setMinor(self):
        self._Severity.setValue("Minor")

    def setNormal(self):
        self._Severity.setValue("Normal")

    def getSeverity(self):
        if self._Severity.hasValue():
            return self._Severity.getValue()

    def _dequote(self, s):
        """
        If a string has single or double quotes around it, remove them.
        Make sure the pair of quotes match.
        If a matching pair of quotes is not found, return the string unchanged.
        """
        if (s[0] == s[-1]) and s.startswith(("'", '"')):
            return s[1:-1]
        return s


    def addIcingaAlarm(self, **kwargs):
        for key, value in kwargs.items():
            value = str(value)
            keywordNOTfound = True
            for alarmproperty in self._AlarmProperties:
                if alarmproperty.matchedKey(key):
                    if self._Severity.matchedKey(key):
                        self.setSeverity(value)
                    elif self._Type.matchedKey(key):
                        self.setType(value)
                    else:
                        alarmproperty.setValue(value)
                    keywordNOTfound=False
            if keywordNOTfound:
                raise FIOKeywordNotFoundException(f'Alarm property not found for KeyWord \'{key}\'. \'{key}={value}\'')
        if (kwargs):
            self.checkMandatoryAttributes(kwargs)

    def checkMandatoryAttributes(self, dictonary):
        for mandatory in self._AlarmKeyProperties:
            if (mandatory.hasValue() == False):
                raise FIOKeywordNotFoundException(f'Alarm property for KeyWord \'{mandatory.getFullName()}\' missing. Submitted Alarm: {dictonary}.')

    def setSeverity(self, pattern_sev):
        found=False
        for key, value in self._lookup_severity.items():
            if type(value) == list:
                for pattern in value:
                    matched = pattern.fullmatch(pattern_sev)
                    if (matched):
                        found = True
                        self._Severity.setValue(key)
            else:
                matched = value.fullmatch(pattern_sev)
                if (matched):
                    found = True
                    self._Severity.setValue(key)
        if found == False:
            # Create exception for wrong Type
            self._Severity.setValue(pattern_sev)

    def setType(self, pattern_type):
        foundType=False
        for key, value in self._lookup_Type.items():
            if type(value) == list:
                for pattern in value:
                    matched = pattern.fullmatch(pattern_type)
                    if (matched):
                        foundType=True
                        self._Type.setValue(key)
            else:
                matched = value.fullmatch(pattern_type)
                if (matched):
                    foundType=True
                    self._Type.setValue(key)
        if foundType==False:
            # Create exception for wrong Type
            self._Type.setValue(pattern_type)

    def _longSeverity(self):
        for key, value in self._reverse_lookup_severity.items():
            #if (value == self._Severity.getValue()):
            if (value.fullmatch(self._Severity.getValue())):
                return key
            #print(f'{value} == {self._Severity.getValue()}')

class FIOKeywordNotFoundException(Exception):
        """ Raised when the alarmline has an KeyWords which is not known. E.g AlertBla. see example,
            Example: Sum="Test case #7 Event 2", msggroup="OSS", Sev="Minor", AlertBla="AlertTestGroup", ag="netcool", AlertKey="/appl/OS2"
        """

        def __init__(self, msg):
            self.msg = msg

        def __repr__(self):
            return self.__str__()

        def __str__(self):
            return "FIOKeywordNotFoundException: {}".format(self.msg)


if __name__ == '__main__':
    # Simple TestCase
    a = IcingaAlarm()

    a.setAlertGroup("TestAlertGroup")
    a.setAlertKey("TestAlertKey")
    a.setMsgGroup("ENG-OSS")
    a.setSummary('This is a text summary for netcool')
    a.setMajor()
    print(a)
    a = IcingaAlarm(); a.setAlertGroup("TestAlertGroup")

    a.setAlertKey("TestAlertKey")
    a.setMsgGroup("ENG-OSS")
    a.setSummary('This is a text summary for netcool')
    a.setMajor()
    print(a.__dict__)
