import sys
import io
from FIO.IcingaOutput import IcingaOutput
import re
from contextlib import redirect_stdout

def check(pattern,returncode,printOut=None):
    rc = None
    f = io.StringIO()
    with redirect_stdout(f):
        rc = a.show()
    out = f.getvalue()

    result = f'F A I L E D - Text Output Wrong.'
    #pattern_escaped = pattern.replace("[","\\[")
    #pattern_escaped = pattern_escaped.replace("?","\\?")
    #if re.search(pattern_escaped,out) and rc == returncode:
    if pattern == out and rc == returncode:
        result = 'PASSED'
    elif rc != returncode:
        result = f"F A I L E D - Return Code Wrong (expected '{returncode}' instead of '{rc}')"
   # print("Output Escaped-----------")
    #print(pattern_escaped)
    #print("Output Normal ------------")
    #print(out)
   # print(f'Return code: {rc} == {returncode}')
    #if (pattern_escaped!=out):
    #        print("ssssssssssssssss")
    #print("------------")
    print(f'result: {result}\n')

    if result != 'PASSED':
        print(f'Generated Output: \n{out}')
        print(f'Expected  Output: \n{pattern}\n\n\n\n')

        #print(f'my retcode: {rc}')
    #print(f'output: \nxxxx{out}xxxx')

ajustresult=80

###########################################################
a = IcingaOutput()
#print('{0: <{1:}}'.format("Test case   1: Standard Long",ajustresult),end='')
print('{0: <{1:}}'.format("Test case   1: Standard Long",ajustresult))
a.addAlarm(   Summary = "Test case #1 Event 1", MsgGroup = "OSS", Severity = "normal" , AlertGroup = "netcool", AlertKey = "/appl/OS1")
a.addAlarm(   Summary = "Test case #1 Event 2", MsgGroup = "OSS", Severity = "normal", AlertGroup = "netcool", AlertKey = "/appl/OS2" )
check("""Checked 2 object(s) -  0 Critical, 0 Major, 0 Minor, 0 Warning, 2 OK
Ok - Test case #1 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 -->
Ok - Test case #1 Event 2  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=0 -->
""", 0)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   2: Standard Critical Warning Long",ajustresult),end='')
a.addAlarm(   Summary = "Test case #2 Event 1", MsgGroup = "OSS", Severity = "Critical" , AlertGroup = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case #2 Event 2", MsgGroup = "OSS", Severity = "warning" , AlertGroup = "netcool", AlertKey = "/appl/OS2" )
check("""Checked 2 object(s) -  1 Critical, 0 Major, 0 Minor, 1 Warning, 0 OK
Critical - Test case #2 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=5 -->
Warning - Test case #2 Event 2  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=2 -->
""", 2)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   3: Standard Warning Critical - output ordered",ajustresult),end='')
a.addAlarm(   Summary = "Test case Event 1", msggroup = "OSS", Sev = "Ok" , AlertGroup = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case Event 2", msggroup = "OSS", Sev = "major", AlertGroup = "netcool", AlertKey = "/appl/OS2" )
a.addAlarm(   Summary = "Test case Event 3", msggroup = "OSS", Sev = "critical", AlertGroup = "netcool", AlertKey = "/appl/OS3" )
#a.set(printOrder=True)
check("""Checked 3 object(s) -  1 Critical, 1 Major, 0 Minor, 0 Warning, 1 OK
Critical - Test case Event 3  [OSS,netcool] <!--  ag=netcool ak=/appl/OS3 mg=OSS Sev=5 -->
Major - Test case Event 2  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=4 -->
Ok - Test case Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 -->
""",2)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   4: Pass unsupported field (surprise=)",ajustresult),end='')
a.addAlarm(   Summary = "Test case #4 Event 1", msggroup = "OSS", Sev = "Ok" , ag = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case #4 Event 2", msggroup = "OSS", surprise="test", Sev = "major", ag="netcool", AlertKey = "/appl/OS2" )
check("""Checked 2 object(s) -  0 Critical, 1 Major, 0 Minor, 0 Warning, 1 OK
Ok - Test case #4 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 -->
Major - FIOKeywordNotFoundException: Alarm property not found for KeyWord 'surprise'. 'surprise=test'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOKeywordNotFoundException_0 mg=OSS Sev=4 tp=14 -->
""",1)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   5: Mandatory Fields",ajustresult),end='')
a.addAlarm(   Summary = "Test case #5 Event 1", msggroup = "OSS", ag = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case #5 Event 2", msggroup = "OSS", Sev = "major", AlertKey = "/appl/OS2" )
check("""Checked 2 object(s) -  0 Critical, 1 Major, 1 Minor, 0 Warning, 0 OK
Major - FIOKeywordNotFoundException: Alarm property for KeyWord 'Severity' missing. Submitted Alarm: {'Summary': 'Test case #5 Event 1', 'msggroup': 'OSS', 'ag': 'netcool', 'AlertKey': '/appl/OS1'}.  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOKeywordNotFoundException_0 mg=OSS Sev=4 tp=14 -->
Minor - FIOKeywordNotFoundException: Alarm property for KeyWord 'AlertGroup' missing. Submitted Alarm: {'Summary': 'Test case #5 Event 2', 'msggroup': 'OSS', 'Sev': 'major', 'AlertKey': '/appl/OS2'}.  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOKeywordNotFoundException_1 mg=OSS Sev=3 tp=14 -->
""",1)


a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   6: Severity Integer",ajustresult),end='')
a.addAlarm(   Summary = "Test case #6 Event 1", msggroup = "OSS", Sev=0, ag = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case #6 Event 2", msggroup = "OSS", Sev=3, ag = "netcool", AlertKey = "/appl/OS2" )
a.addAlarm(   Summary = "Test case #6 Event 3", msggroup = "OSS", Sev=2, ag = "netcool", AlertKey = "/appl/OS3" )
a.addAlarm(   Summary = "Test case #6 Event 4", msggroup = "OSS", Sev=5, ag = "netcool", AlertKey = "/appl/OS4" )
a.addAlarm(   Summary = "Test case #6 Event 5", msggroup = "OSS", Sev=4, ag = "netcool", AlertKey = "/appl/OS5" )

check("""Checked 5 object(s) -  1 Critical, 1 Major, 1 Minor, 1 Warning, 1 OK
Critical - Test case #6 Event 4  [OSS,netcool] <!--  ag=netcool ak=/appl/OS4 mg=OSS Sev=5 -->
Major - Test case #6 Event 5  [OSS,netcool] <!--  ag=netcool ak=/appl/OS5 mg=OSS Sev=4 -->
Minor - Test case #6 Event 2  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=3 -->
Warning - Test case #6 Event 3  [OSS,netcool] <!--  ag=netcool ak=/appl/OS3 mg=OSS Sev=2 -->
Ok - Test case #6 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 -->
""",2)


a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   7: Severity as text",ajustresult),end='')
a.addAlarm(   Summary = "Test case #7 Event 1", msggroup = "OSS", Sev="ok", ag = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case #7 Event 2", msggroup = "OSS", Sev="minor", ag = "netcool", AlertKey = "/appl/OS2" )
a.addAlarm(   Summary = "Test case #7 Event 3", msggroup = "OSS", Sev="warning", ag = "netcool", AlertKey = "/appl/OS3" )
a.addAlarm(   Summary = "Test case #7 Event 4", msggroup = "OSS", Sev="critical", ag = "netcool", AlertKey = "/appl/OS4" )
a.addAlarm(   Summary = "Test case #7 Event 5", msggroup = "OSS", Sev="MaJor", ag = "netcool", AlertKey = "/appl/OS5" )

check("""Checked 5 object(s) -  1 Critical, 1 Major, 1 Minor, 1 Warning, 1 OK
Critical - Test case #7 Event 4  [OSS,netcool] <!--  ag=netcool ak=/appl/OS4 mg=OSS Sev=5 -->
Major - Test case #7 Event 5  [OSS,netcool] <!--  ag=netcool ak=/appl/OS5 mg=OSS Sev=4 -->
Minor - Test case #7 Event 2  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=3 -->
Warning - Test case #7 Event 3  [OSS,netcool] <!--  ag=netcool ak=/appl/OS3 mg=OSS Sev=2 -->
Ok - Test case #7 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 -->
""",2)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   8: Duplcate ag and ak",ajustresult),end='')
a.addAlarm(   Summary = "Test case #8 Event 1", msggroup = "OSS", Sev="ok", ag = "netcool", AlertKey = "/appl/OS1" )
a.addAlarm(   Summary = "Test case #8 Event 2", msggroup = "OSS", Sev="minor", ag = "netcool", AlertKey = "ident ident" )
a.addAlarm(   Summary = "Test case #8 Event 3", msggroup = "OSS", Sev="warning", ag = "netcool", AlertKey = "/appl/OS3" )
a.addAlarm(   Summary = "Test case #8 Event 4", msggroup = "OSS", Sev="critical", ag = "netcool", AlertKey = "ident ident" )
a.addAlarm(   Summary = "Test case #8 Event 5", msggroup = "OSS", Sev="MaJor", ag = "netcool", AlertKey = "/appl/OS5" )

check("""Checked 6 object(s) -  1 Critical, 2 Major, 1 Minor, 1 Warning, 1 OK
Critical - Test case #8 Event 4  [OSS,netcool] <!--  ag=netcool ak="ident ident" mg=OSS Sev=5 -->
Major - Test case #8 Event 5  [OSS,netcool] <!--  ag=netcool ak=/appl/OS5 mg=OSS Sev=4 -->
Minor - Test case #8 Event 2  [OSS,netcool] <!--  ag=netcool ak="ident ident" mg=OSS Sev=3 -->
Warning - Test case #8 Event 3  [OSS,netcool] <!--  ag=netcool ak=/appl/OS3 mg=OSS Sev=2 -->
Ok - Test case #8 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 -->
Major - Found 1 duplicate(s) for 'AlertGroup=netcool AlertKey='ident ident''  [OSS,PluginFailure] <!--  ag=PluginFailure ak=Duplicate_AlertGroup_AND_AlertKey_0 mg=OSS Sev=4 tp=14 -->
Minor - Found 1 duplicate(s) for 'AlertGroup=netcool AlertKey='ident ident''  [OSS,PluginFailure] <!--  ag=PluginFailure ak=Duplicate_AlertGroup_AND_AlertKey_1 mg=OSS Sev=3 tp=14 -->
""",2)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case   9: Type Values",ajustresult),end='')
a.addAlarm(   Summary = "Test case #9 Event 1", msggroup = "OSS", Sev=0, ag = "netcool", AlertKey = "/appl/OS1", Type=1 )
a.addAlarm(   Summary = "Test case #9 Event 5", msggroup = "OSS", Sev=4, ag = "netcool", AlertKey = "/appl/OS2", Type=2 )
a.addAlarm(   Summary = "Test case #9 Event 5", msggroup = "OSS", Sev=4, ag = "netcool", AlertKey = "/appl/OS3", Type="NAA" )

check("""Checked 3 object(s) -  0 Critical, 2 Major, 0 Minor, 0 Warning, 1 OK
Major - Test case #9 Event 5  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=4 tp=2 -->
Major - Test case #9 Event 5  [OSS,netcool] <!--  ag=netcool ak=/appl/OS3 mg=OSS Sev=4 tp=14 -->
Ok - Test case #9 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 tp=1 -->
""",1)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  10: Unsupported Type",ajustresult),end='')
a.addAlarm(   Summary = "Test case #10 Event 1", msggroup = "OSS", Sev=0, ag = "netcool", AlertKey = "/appl/OS1", Type=1 )
a.addAlarm(   Summary = "Test case #10 Event 5", msggroup = "OSS", Sev=4, ag = "netcool", AlertKey = "/appl/OS2", Type="NA" )

check("""Checked 2 object(s) -  0 Critical, 1 Major, 0 Minor, 0 Warning, 1 OK
Ok - Test case #10 Event 1  [OSS,netcool] <!--  ag=netcool ak=/appl/OS1 mg=OSS Sev=0 tp=1 -->
Major - FIOPatternException: Pattern validation error for 'Type=NA'. Allowed pattern '14|NAA|NAC|1|Problem|2|Resolution|13|Information'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_0 mg=OSS Sev=4 tp=14 -->
""",1)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  11: Length Check",ajustresult),end='')
a.addAlarm(   Summary = "Test case #11 Event 1", msggroup = "OSS", Sev=0, ag = "netcool", AlertKey = "/appl/OS1", NEIPAddress="1234567890ß1234567" )
a.addAlarm(   Summary = "Test case #11 Event 5", msggroup = "OSS", Sev=4, ag = "netcool", AlertKey = "/appl/OS2"  )

check("""Checked 2 object(s) -  0 Critical, 2 Major, 0 Minor, 0 Warning, 0 OK
Major - Test case #11 Event 5  [OSS,netcool] <!--  ag=netcool ak=/appl/OS2 mg=OSS Sev=4 -->
Major - FIOPatternException: Pattern validation error for 'NEIPAddress=1234567890ß1234567'. Allowed pattern '\d+\.\d+\.\d+\.\d+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_0 mg=OSS Sev=4 tp=14 -->
""",1)

#### Todo Perrth other tests



a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  22: ARS Fields",ajustresult),end='')
a.addAlarm(   Summary = "Test case #22 Event 1", mg="OSS", sev=3, ag="ag", ak="1", arsgroup="noc" )
a.addAlarm(   Summary = "Test case #22 Event 2", mg="OSS", sev=3, ag="ag", ak="2", asg="oss" )
a.addAlarm(   Summary = "Test case #22 Event 3", mg="OSS", sev=3, ag="ag", ak="3", arsopCat1="Fault" )
a.addAlarm(   Summary = "Test case #22 Event 4", mg="OSS", sev=3, ag="ag", ak="4", as2="generic" )
a.addAlarm(   Summary = "Test case #22 Event 5", mg="OSS", sev=3, ag="ag", ak="5", ass="max muster" )
a.addAlarm(   Summary = "Test case #22 Event 6", mg="OSS", sev=3, ag="ag", ak="6", arssubmitter="potter" )
a.addAlarm(   Summary = "Test case #22 Event 7", mg="OSS", sev=3, ag="ag", ak="7", arsurgency="4000" )
a.addAlarm(   Summary = "Test case #22 Event 8", mg="OSS", sev=3, ag="ag", ak="8", asu="2000" )

check("""Checked 8 object(s) -  0 Critical, 1 Major, 7 Minor, 0 Warning, 0 OK
Minor - Test case #22 Event 1  [OSS,ag] <!--  ag=ag ak=1 asg=noc mg=OSS Sev=3 -->
Minor - Test case #22 Event 2  [OSS,ag] <!--  ag=ag ak=2 asg=oss mg=OSS Sev=3 -->
Minor - Test case #22 Event 3  [OSS,ag] <!--  ag=ag ak=3 as1=Fault mg=OSS Sev=3 -->
Minor - Test case #22 Event 4  [OSS,ag] <!--  ag=ag ak=4 as2=generic mg=OSS Sev=3 -->
Minor - Test case #22 Event 6  [OSS,ag] <!--  ag=ag ak=6 ass=potter mg=OSS Sev=3 -->
Minor - Test case #22 Event 7  [OSS,ag] <!--  ag=ag ak=7 asu=4000 mg=OSS Sev=3 -->
Minor - Test case #22 Event 8  [OSS,ag] <!--  ag=ag ak=8 asu=2000 mg=OSS Sev=3 -->
Major - FIOPatternException: Pattern validation error for 'ARSSubmitter=max muster'. Allowed pattern '\S+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_0 mg=OSS Sev=4 tp=14 -->
""",1)


a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  23: Class and Technology",ajustresult),end='')
a.addAlarm(   Summary = "Test case #23 Event 1", mg="OSS", sev=3, ag="ag", ak="1", Class="8" )
a.addAlarm(   Summary = "Test case #23 Event 2", mg="OSS", sev=3, ag="ag", ak="2", cl="310" )
a.addAlarm(   Summary = "Test case #23 Event 3", mg="OSS", sev=3, ag="ag", ak="3", Technology="2G" )
a.addAlarm(   Summary = "Test case #23 Event 4", mg="OSS", sev=3, ag="ag", ak="4", te="LTE" )

check("""Checked 4 object(s) -  0 Critical, 0 Major, 4 Minor, 0 Warning, 0 OK
Minor - Test case #23 Event 1  [OSS,ag] <!--  ag=ag ak=1 cl=8 mg=OSS Sev=3 -->
Minor - Test case #23 Event 2  [OSS,ag] <!--  ag=ag ak=2 cl=310 mg=OSS Sev=3 -->
Minor - Test case #23 Event 3  [OSS,ag] <!--  ag=ag ak=3 mg=OSS Sev=3 te=2G -->
Minor - Test case #23 Event 4  [OSS,ag] <!--  ag=ag ak=4 mg=OSS Sev=3 te=LTE -->
""",1)


a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  24: SuppressEscl",ajustresult),end='')
a.addAlarm(   Summary = "Test case #24 Event 1", mg="OSS", sev=3, ag="ag", ak="1", SuppressEscl="20" )
a.addAlarm(   Summary = "Test case #24 Event 2", mg="OSS", sev=3, ag="ag", ak="2", se="10" )
a.addAlarm(   Summary = "Test case #24 Event 3", mg="OSS", sev=3, ag="ag", ak="3", SuppressEscl="0" )

check("""Checked 3 object(s) -  0 Critical, 1 Major, 2 Minor, 0 Warning, 0 OK
Minor - Test case #24 Event 1  [OSS,ag] <!--  ag=ag ak=1 mg=OSS Sev=3 se=20 -->
Minor - Test case #24 Event 3  [OSS,ag] <!--  ag=ag ak=3 mg=OSS Sev=3 se=0 -->
Major - FIOPatternException: Pattern validation error for 'SuppressEscl=10'. Allowed pattern '0|20|23'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_0 mg=OSS Sev=4 tp=14 -->
""",1)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  25: ForceResend",ajustresult),end='')
a.addAlarm(   Summary = "Test case #25 Event 1", mg="OSS", sev=3, ag="ag", ak="1", ForceResend="1" )
a.addAlarm(   Summary = "Test case #25 Event 2", mg="OSS", sev=3, ag="ag", ak="2", fr="1" )

check("""Checked 2 object(s) -  0 Critical, 0 Major, 2 Minor, 0 Warning, 0 OK
Minor - Test case #25 Event 1  [OSS,ag] <!--  ag=ag ak=1 mg=OSS Sev=3 fr=1 -->
Minor - Test case #25 Event 2  [OSS,ag] <!--  ag=ag ak=2 mg=OSS Sev=3 fr=1 -->
""",1)



a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  26: Check quotes ' and \"",ajustresult),end='')
a.addAlarm(   Summary = "Test case #26 Event 1", mg="OSS", sev=3, ag="ag", ak="1", ExtendedAttr="""new lines \
must\n \r\nbe replaced""" )
a.addAlarm(   Summary = "Test case #26 Event 2", mg="OSS", sev=3, ag="ag", ak="2", ea="double quotes \"must be replaced\" with single qoutes ' ." )

check("""Checked 2 object(s) -  0 Critical, 0 Major, 2 Minor, 0 Warning, 0 OK
Minor - Test case #26 Event 1  [OSS,ag] <!--  ag=ag ak=1 mg=OSS Sev=3 ea="new lines must be replaced" -->
Minor - Test case #26 Event 2  [OSS,ag] <!--  ag=ag ak=2 mg=OSS Sev=3 ea="double quotes 'must be replaced' with single qoutes ' ." -->
""",1)


a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  27: Multiple Fields",ajustresult),end='')
a.addAlarm(   Summary = "Test case #27 Event 1", mg="OSS", sev=3, ag="ag", ak="1", ForceResend="1", ci="ci", dy="10", eqt="eqt", eid="eid", hk="hk", lo="lo", nfo="123123", poll="30", ne="172.171.170.162")
a.addAlarm(   Summary = "Test case #27 Event 2", mg="OSS", sev=3, ag="ag", ak="2", ciid="ciid", HelpKey="help", delay="20", uRL="https://orf.at?hallo='1'", email="a.b@c.com", vce="ab2", si="SQM-002")

check("""Checked 2 object(s) -  0 Critical, 0 Major, 2 Minor, 0 Warning, 0 OK
Minor - Test case #27 Event 1  [OSS,ag] <!--  ag=ag ak=1 ci=ci dy=10 mg=OSS nfo=123123 po=30 Sev=3 ne=172.171.170.162 eqt=eqt eid=eid hk=hk lo=lo fr=1 -->
Minor - Test case #27 Event 2  [OSS,ag] <!--  ag=ag ak=2 ci=ciid dy=20 mg=OSS Sev=3 si=SQM-002 URL=https://orf.at?hallo='1' hk=help em=a.b@c.com vce=ab2 -->
""",1)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  28: Interger Fields",ajustresult),end='')
a.addAlarm(   Summary = "Test case #28 Event 1", mg="OSS", sev=3, ag="ag", ak="1", dy="10.0")
a.addAlarm(   Summary = "Test case #28 Event 2", mg="OSS", sev=3, ag="ag", ak="2", poll="")
a.addAlarm(   Summary = "Test case #28 Event 3", mg="OSS", sev=3, ag="ag", ak="3", expiretime="-10")
a.addAlarm(   Summary = "Test case #28 Event 4", mg="OSS", sev=3, ag="ag", ak="4", nefirstoccurrence="3Tage")
a.addAlarm(   Summary = "Test case #28 Event 5", mg="OSS", sev=3, ag="ag", ak="5", pr="10,8")

check("""Checked 5 object(s) -  0 Critical, 1 Major, 4 Minor, 0 Warning, 0 OK
Major - FIOPatternException: Pattern validation error for 'Delay=10.0'. Allowed pattern '\d+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_0 mg=OSS Sev=4 tp=14 -->
Minor - FIOPatternException: Pattern validation error for 'Poll='. Allowed pattern '\d+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_1 mg=OSS Sev=3 tp=14 -->
Minor - FIOPatternException: Pattern validation error for 'ExpireTime=-10'. Allowed pattern '\d+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_2 mg=OSS Sev=3 tp=14 -->
Minor - FIOPatternException: Pattern validation error for 'NEFirstOccurrence=3Tage'. Allowed pattern '\d+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_3 mg=OSS Sev=3 tp=14 -->
Minor - FIOPatternException: Pattern validation error for 'ProcessReq=10,8'. Allowed pattern '\d+'  [OSS,PluginFailure] <!--  ag=PluginFailure ak=FIOPatternException_4 mg=OSS Sev=3 tp=14 -->
""",1)

a = IcingaOutput()
print('{0: <{1:}}'.format("Test case  99: No AlertKey",ajustresult),end='')
a.addAlarm(   Summary = "Test case #99 Event 1", mg="OSS", sev=3, ag="ag" )

check("""Checked 1 object(s) -  0 Critical, 0 Major, 1 Minor, 0 Warning, 0 OK
Minor - Test case #99 Event 1  [OSS,ag] <!--  ag=ag mg=OSS Sev=3 -->
""",1)

