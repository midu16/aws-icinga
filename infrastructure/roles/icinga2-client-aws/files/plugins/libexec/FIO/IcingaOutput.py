# -*- coding: utf-8 -*-
import sys
from FIO.IcingaAlarm import IcingaAlarm
from FIO.IcingaPerfdata import IcingaPerfdata
# Version 0.6 with all testcases expact addText and addLine

# Todo ignor duplciate for logfile monitoring
class IcingaOutput():


    def __init__(self):
        self._defaultMsgGroup= "OSS"
        self._ignoreDupicateAlertGroupAndKey= False
        self._defaultHeader = ''
        self._alarm_list = []
        self._alarm_error = []
        self._duplicates = []
        self._perf_list = []
        self._count_crit = 0
        self._count_major = 0
        self._count_minor = 0
        self._count_warning = 0
        self._count_normal = 0
        self._count_all =0
        self._exitCode = 0

    def setDefaultMsgGroup(self, MsgGroup):
        self._defaultMsgGroup=MsgGroup

    def addAlarm(self, **kwargs):
        try:
            alarm = IcingaAlarm()
            alarm.addIcingaAlarm(**kwargs)
            #alarm.checkMandatoryAttributes()
            self._alarm_list.append(alarm)
        except Exception as e:
            self._alarmhandler(e)

    def addPerfdata(self, **kwargs):
        try:
            perf = IcingaPerfdata()
            perf.addPerfData(**kwargs)
            self._perf_list.append(perf)
        except Exception as e:
            self._alarmhandler(e)


    def _alarmhandler(self, exception):
        a = IcingaAlarm()
        if self._alarm_error:
            a.setSeverity('Minor')
        else:
            a.setSeverity('Major')
        a.setAlertGroup("PluginFailure")
        a.setMsgGroup(self._defaultMsgGroup)
        a.setType("NAC")
        a.setAlertKey(f'{exception.__class__.__name__}_{len(self._alarm_error)}')
        a.setSummary(exception.__str__())
        self._alarm_error.append(a)

    def print(self):
        exit = self._exitPlugin()
        print(self._defaultHeader)
        self._printList(sorted(self._alarm_list))
        #self._printList(self._alarm_error)
        if not self._ignoreDupicateAlertGroupAndKey:
            self._checkDuplicates()
            self._createDuplicateAlarm()
        self._printList(self._alarm_error)
        if self._perf_list:
            self._printPerf()
        sys.exit(exit)

    def show(self):
        exit = self._exitPlugin()
        print(self._defaultHeader)
        self._printList(sorted(self._alarm_list))
        #self._printList(self._alarm_error)
        if not self._ignoreDupicateAlertGroupAndKey:
            self._checkDuplicates()
            self._createDuplicateAlarm()
        self._printList(self._alarm_error)
        if self._perf_list:
            self._printPerf()
        return exit

    def _printList(self, list):
        for i in list:
            print(i)

    def _printPerf(self):
        print("|", end=" ")
        for i in self._perf_list:
            print(i, end=" ")

    def _unique_list(self,l):
        x = []
        for a in l:
            if a not in x:
                x.append(a)
        return x


    def _checkDuplicates(self):
        for i in self._alarm_list:
            found = False
            count = 0
            for o in self._alarm_list:
                if i.checkDuplicates(o.getDuplicateClearAttributes()):
                    found = True
                    count = count + 1
            if found:
                if count > 1:
                    duplicates = count -1
                    self._duplicates.append(f'Found {duplicates} duplicate(s) for \'{i.getDuplicateClearAttributes()}\'')

        #print(self._unique_list(self._duplicates))


    def _createDuplicateAlarm(self):
        for dup in self._unique_list(self._duplicates):
            a = IcingaAlarm()
            if self._alarm_error:
                a.setSeverity('Minor')
            else:
                a.setSeverity('Major')
            a.setAlertGroup("PluginFailure")
            a.setMsgGroup(self._defaultMsgGroup)
            a.setType("NAC")
            a.setAlertKey(f'Duplicate_AlertGroup_AND_AlertKey_{len(self._alarm_error)}')
            a.setSummary(dup)
            self._alarm_error.append(a)

    def _exitPlugin(self):
        all_alarms = []
        all_alarms.extend(self._alarm_list)
        if not self._ignoreDupicateAlertGroupAndKey:
            self._checkDuplicates()
            self._createDuplicateAlarm()
        all_alarms.extend(self._alarm_error)
        for alarm in all_alarms:
            if (alarm.getSeverity() == '5'):
                self._count_crit+=1
                self._setExitCode(2)
            if (alarm.getSeverity() == '4'):
                self._count_major += 1
                self._setExitCode(1)
            if (alarm.getSeverity() == '3'):
                self._count_minor += 1
                self._setExitCode(1)
            if (alarm.getSeverity() == '2'):
                self._count_warning += 1
                self._setExitCode(1)
            if (alarm.getSeverity()  == '0'):
                self._count_normal+=1
                self._setExitCode(0)
        self._count_all=self._count_normal + self._count_crit + self._count_major + self._count_minor + self._count_warning
        self._defaultHeader= f'Checked {self._count_all} object(s) -  {self._count_crit} Critical, {self._count_major} Major, {self._count_minor} Minor, {self._count_warning} Warning, {self._count_normal} OK'
        return self._exitCode

    def _setExitCode(self, exitCode):
        #print(self._exitCode)
        if (self._exitCode < exitCode):
            #print(self._exitCode)
            self._exitCode = exitCode


if __name__ == '__main__':
    # Simple TestCase
    a = IcingaOutput()
    a.setDefaultMsgGroup("ENG-OSS")
    #a.addAlarm(Summary="Test case #7 Event 1", msggrou="OSS", Sev="minor", AlertGroup="netcool", AlertKey="/appl/OS1")
    #a.addAlarm(Summary="Test case #7 Event 2", msggroup="OSS", Sev="Minor", AlertGroup="netcool1", AlertKey="/appl/OS1")
   # a.addAlarm(Summary="Test case #7 Event 3", msggroup="OSS", Sev="Minor", AlertGroup="netcool1", AlertKey="/appl/OS1")

    #a.addAlarm(Summary="Test case #7 Event 4", msggroup="OSS", Sev="Minor", AlertGroup="netcool3", AlertKey="/appl/OS1")
   # a.addAlarm(Summary="Test case #7 Event 5", msggroup="OSS", Sev="Minor", AlertGroup="netcool4", AlertKey="/appl/OS1")
    #a.addAlarm(Summary="Test case #7 Event 6", msggrou="OSS", Sev="0", AlertGroup="netcool1", AlertKey="/appl/OS1")
   # a.addAlarm(Summary="Test case #7 Event 6", msggroup="OSS", Sev="0", AlertGroup="netcool1", AlertKey="/appl/OS1")
    a.addAlarm(Summary="Test case #7 Event 7", msggroupr="OSS", Sev="Critical", AlertGroup='netcool4 is da', AlertKey="/appl/OS1")
    a.addAlarm(Summary="Test case #4 Event 2", msggroup="OSS", surprise="test", Sev="major", ag="netcool", AlertKey="/appl/OS2")
   # a.addAlarm(Summary="Test case #7 Event 8", msggroup="OSS", Sev="Minor", AlertGroup="netcool1", AlertKey="/appl/OS1")
   # a.addAlarm(Summary="Test case #7 Event 9", msggroup="OSS", Sev="Minor", ag="nagios", AlertKey="/appl/OS1")
    a.addPerfdata(Name="/app/OSS", Value="20", Unit="MB")
    a.addPerfdata(Name="/app/Billing", Value="20", Unit="GB")
    #a.addAlarm(Sum="Test case #7 Event 2", msggroup="OS", Sev="Minor", ag="netcool", AlertGroup="bla", AlertKey="/appl/OS2")
    #a.addAlarm(Summary="Test case #7 Event 3", msggroup="OSS", Sev="warning", ag="netcool", AlertKey="/appl/OS3")
    #a.addAlarm(Summary="Test case #7 Event 4", msggroup="OSS", Sev="Critical", ag="netcool", AlertKey="/appl/OS4")
    #a.addAlarm(Summary="Test case #7 Event 5", msggroup="OSS", Sev="Major", ag="netcool", AlertKey="/appl/OS5")
    a.print()
    #a.printPerf()

