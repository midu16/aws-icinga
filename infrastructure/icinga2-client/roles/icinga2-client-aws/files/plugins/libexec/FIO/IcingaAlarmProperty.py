# -*- coding: utf-8 -*-
import re


class IcingaAlarmProperty():
    """Class for an Icinga2 Alarm property. Examples <!-- AlertGroup=TestGroup AlertKey=TestKey --> """

    def __init__(self, fullname, shortname, pattern, allowedLength, default_value=None):
        # default value only used for AlertKey
        self._fullname = fullname
        self._shortname = shortname
        self._pattern = re.compile(pattern, re.IGNORECASE)
        self._spacepattern = re.compile('\\s')
        self._alloweLength = allowedLength
        self._value = default_value

    def getFullName(self):
        return self._fullname

    def setValue(self, value):
        value = value.replace("\n", "")
        value = value.replace("\r", "")
        value = value.replace('\"', "'")
        matched = self._pattern.fullmatch(value)
        #print(f'xxxxxx!Value: {self._fullname} == {self._value}')
        if matched:
            if self.hasValue():
                raise FIOKeywordRepeatedException(f'Alarm property repeated failure for {self._fullname}')
            self._value = value
            #print(f'!!!!!!!!!Value: {self._fullname} == {self._value}')
            #print(f'Key: {self._fullname} Type: {type(self._value)}')
        else:
            raise FIOPatternException(f'Pattern validation error for \'{self._fullname}={value}\'. Allowed pattern \'{self._pattern.pattern}\'')
        if len(value) > self._alloweLength:
            self._value = value[0:self._alloweLength]
            raise FIOLengthException(f'Length validation error for \'{self._fullname}\' . Value length {len(value)}. '
                                     f'Allowed length {self._alloweLength}.')

    def hasValue(self):
        if self._value:
            return True
        else:
            return False

    def _matchedSpace(self):
        if self._spacepattern.findall(self._value):
            return True

    def getValue(self):
        if self._matchedSpace():
            return f'"{self._value}"'
        return self._value

    def getIcingaFormatLongNameProp(self):
        if self._value:
            return f'{self._fullname}={self.getValue()}'
        return ''

    def getIcingaFormatShortNameProp(self):
        if self._value:
            return f'{self._shortname}={self.getValue()}'
        return ''

    def getIcingaFormatPerfData(self):
        if self._value:
            return f'{self._value}'


    def matchedKey(self, value):
        """longvalue means AlertGoup not ag"""
        if self._fullname.lower() == value.lower():
            #print(f'FullName attribute matched: {self._fullname} == {value}')
            return True
        if self._shortname.lower() == value.lower():
            #print(f'Shortname attribute matched: {self._shortname} == {value}')
            return True
        return False



    def __str__(self):
        return f'IcingaAlarmProperty [{self._fullname}={self._value}] '


class FIOPatternException(Exception):
    """Raised when the pattern does not match"""

    def __init__(self, msg):
        self.msg = msg

    def __repr__(self):
        return self.__str__()

    def __str__(self):
        return "FIOPatternException: {}".format(self.msg)


class FIOKeywordRepeatedException(Exception):
    """ Raised when the alarmline has duplicate KeyWords. E.g AlertGroup. see example,
        Example: Sum="Test case #7 Event 2", msggroup="OSS", Sev="Minor", AlertGroup="alertgrup", ag="netcool", AlertKey="/appl/OS2"
    """

    def __init__(self, msg):
        self.msg = msg

    def __repr__(self):
        return self.__str__()


    def __str__(self):
        return "FIOKeywordRepeatedException: {}".format(self.msg)


class FIOLengthException(Exception):
    """Raised when the length of the value does not match. Value will be reduced to allowed length"""

    def __init__(self, msg):
        self.msg = msg

    def __repr__(self):
        return self.__str__()


    def __str__(self):
        return "FIOPatternException: {}".format(self.msg)



if __name__ == '__main__':
    # Simple TestCase
    test = IcingaAlarmProperty("AlertGroup", "ag", ".*", 10)
    try:
        test.setValue("bklaksdaljksdf asdljkfasdlkfjöl kasdkljfa dfj")
    except FIOLengthException as e:
        print(test)
        print("Test FIO Called")
