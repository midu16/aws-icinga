# -*- coding: utf-8 -*-
from FIO.IcingaAlarmProperty import IcingaAlarmProperty

class IcingaPerfdata():
    def __init__(self):
        self._PerfDataProperties = []
        self._PerfName = IcingaAlarmProperty("Name", "name", "\\S+", 255)
        self._PerfValue = IcingaAlarmProperty("Value", "val", "([+-]?\\d+(\\.\\d+)?)", 255)
        self._PerfUnit = IcingaAlarmProperty("Unit", "unit", "\\S+", 255)
        self._PerfWarn = IcingaAlarmProperty("PerfWarn", "warn", "([+-]?\\d+(\\.\\d+)?)", 255)
        self._PerfCrit = IcingaAlarmProperty("PerfCrit", "crit", "([+-]?\\d+(\\.\\d+)?)", 255)
        self._PerfMin = IcingaAlarmProperty("PerfMin", "min", "([+-]?\\d+(\\.\\d+)?)", 255)
        self._PerfMax = IcingaAlarmProperty("PerfMax", "max", "([+-]?\\d+(\\.\\d+)?)", 255)

        self._PerfDataProperties = [self._PerfName, self._PerfValue, self._PerfUnit, self._PerfWarn, self._PerfCrit, self._PerfMax, self._PerfMin, self._PerfMax]
        self._PerfDataOut = [self._PerfUnit, self._PerfWarn, self._PerfCrit,
                                    self._PerfMax, self._PerfMin, self._PerfMax]

    def setPerfName(self, name):
        """Current token of icinga2 perfvalue"""
        self._PerfName.setValue(name)

    def setPerfValue(self, value):
        """Current token of icinga2 perfvalue"""
        self._PerfValue.setValue(value)

    def setPerfUnit(self, perf_unit):
        """Important Alarm Property for Netcool Clearing"""
        self._PerfUnit.setValue(perf_unit)

    def setPerfWarn(self, perf_warn):
        """Important Alarm Property for Netcool Clearing"""
        self._PerfWarn.setValue(perf_warn)

    def setPerfCrit(self, perf_crit):
        self._PerfCrit.setValue(perf_crit)

    def setPerfMin(self, perf_min):
        """Important Alarm Property for Netcool """
        self._PerfMin.setValue(perf_min)

    def setPerfMax(self, perf_max):
        """Important Alarm Property for Netcool """
        self._PerfMax.setValue(perf_max)

    def __str__(self):
        value=f'{self._PerfName.getIcingaFormatPerfData()}={self._PerfValue.getIcingaFormatPerfData()}'
        for string in self._PerfDataOut:
            if string.getIcingaFormatPerfData():
                value = f'{value};{string.getIcingaFormatPerfData()}'
        #return f'{self._PerfName.getIcingaFormatPerfData()}={self._PerfValue.getIcingaFormatPerfData()};{self._PerfUnit.getIcingaFormatPerfData()};{self._PerfWarn.getIcingaFormatPerfData()};{self._PerfCrit.getIcingaFormatPerfData()};{self._PerfMin.getIcingaFormatPerfData()};{self._PerfMax.getIcingaFormatPerfData()} '
        return value


    def addPerfData(self, **kwargs):
        for key, value in kwargs.items():
            keywordNOTfound = True
            for perfproperty in self._PerfDataProperties:
                if perfproperty.matchedKey(key):
                    perfproperty.setValue(value)
                    keywordNOTfound=False
            if keywordNOTfound:
                raise FIOKeywordNotFoundException(f'Alarm property not found for KeyWord \'{key}\'. \'{key}={value}\'')

class FIOPerfKeywordNotFoundException(Exception):
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
    a = IcingaPerfdata()
    a.setPerfName("/app/OSS")
    a.setPerfValue("50.10")
    a.setPerfUnit("MB")
    a.setPerfMin("20")
    a.setPerfMax("100")
    a.setPerfWarn("60")
    a.setPerfCrit("70")
    print(a)
