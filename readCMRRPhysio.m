function physio = readCMRRPhysio(fn)
% -------------------------------------------------------------------------
% readCMRRPhysio.m
% -------------------------------------------------------------------------
% Read physiological log files from CMRR MB sequences (>=R013, >=VD13A)
%   E. Auerbach, CMRR, 2015
%
% Usage:
%    physio = readCMRRPhysio(base_filename);
%
% This function expects to find _ECG, _RESP, _PULS, _EXT, and _Info
% files, and will return physio traces for ECG1, ECG2, ECG3, ECG4, RESP,
% PULS, EXT1, and EXT2 signals. Only active traces (with nonzero values)
% will be returned.
%
% Inputs:
%    base_filename = 'Physio_DATE_TIME_UUID'
%
% Returns:
%    The unit of time is clock ticks (2.5 ms per tick).
%        physio.UUID: unique identifier string for this measurement
%        physio.SliceMap: [2 x Volumes x Slices] array
%            (1,:,:) = start time stamp of each volume/slice
%            (2,:,:) = start time stamp of each volume/slice
%        physio.ACQ: [total scan time x 1] array
%            value = 1 if acquisition is active at this time; 0 if not
%        physio.ECG1: [total scan time x 1] array
%        physio.ECG2: [total scan time x 1] array
%        physio.ECG3: [total scan time x 1] array
%        physio.ECG4: [total scan time x 1] array
%            value = ECG signal on this channel
%        physio.RESP: [total scan time x 1] array
%            value = RESP signal on this channel
%        physio.PULS: [total scan time x 1] array
%            value = PULS signal on this channel
%        physio.EXT: [total scan time x 1] array
%            value = 1 if EXT signal detected; 0 if not
%        physio.EXT2: [total scan time x 1] array
%            value = 1 if EXT2 signal detected; 0 if not

% this is the file format this function expects; must match log file version
ExpectedVersion = 'EJA_1';

% say hello
fprintf('\nreadCMRRPhysio: E. Auerbach, CMRR, 2015\n\n');

% first, check whether we have all of the files
fnINFO = [fn '_Info.log'];
fnECG  = [fn '_ECG.log'];
fnRESP = [fn '_RESP.log'];
fnPULS = [fn '_PULS.log'];
fnEXT  = [fn '_EXT.log'];
if (2 ~= exist(fnINFO, 'file')), error('%s not found!', fnINFO); end
if (2 ~= exist(fnECG , 'file')), error('%s not found!' , fnECG); end
if (2 ~= exist(fnRESP, 'file')), error('%s not found!', fnRESP); end
if (2 ~= exist(fnPULS, 'file')), error('%s not found!', fnPULS); end
if (2 ~= exist(fnEXT , 'file')), error('%s not found!' , fnEXT ); end

% read in the data
[SliceMap, UUID1, NumSlices, NumVolumes, FirstTime, LastTime] = readParseFile(fnINFO, 'ACQUISITION_INFO', ExpectedVersion, 0, 0);
if (LastTime <= FirstTime), error('Last timestamp is not greater than first timestamp, aborting...'); end
ActualSamples = LastTime - FirstTime + 1;
ExpectedSamples = ActualSamples + 8; % some padding at the end for worst case EXT sample at last timestamp

[ECG, UUID2] = readParseFile(fnECG, 'ECG', ExpectedVersion, FirstTime, ExpectedSamples);
if (~strcmp(UUID1, UUID2)), error('UUID mismatch between Info and ECG files!'); end

[RESP, UUID3] = readParseFile(fnRESP, 'RESP', ExpectedVersion, FirstTime, ExpectedSamples);
if (~strcmp(UUID1, UUID3)), error('UUID mismatch between Info and RESP files!'); end

[PULS, UUID4] = readParseFile(fnPULS, 'PULS', ExpectedVersion, FirstTime, ExpectedSamples);
if (~strcmp(UUID1, UUID4)), error('UUID mismatch between Info and PULS files!'); end

[EXT, UUID5] = readParseFile(fnEXT, 'EXT', ExpectedVersion, FirstTime, ExpectedSamples);
if (~strcmp(UUID1, UUID5)), error('UUID mismatch between Info and EXT files!'); end

fprintf('Formatting data...\n');
ACQ = zeros(ExpectedSamples,1,'uint16');
for v=1:NumVolumes
    for s=1:NumSlices
        ACQ(SliceMap(1,v,s)+1:SliceMap(2,v,s)+1,1) = 1;
    end
end
    
fprintf('\n');
fprintf('Slices in scan:      %d\n', NumSlices);
fprintf('Volumes in scan:     %d\n', NumVolumes);
fprintf('First timestamp:     %d\n', FirstTime);
fprintf('Last timestamp:      %d\n', LastTime);
fprintf('Total scan duration: %d ticks\n', ActualSamples);
fprintf('Total scan duration: %.4f s\n', double(ActualSamples)*2.5/1000);
fprintf('\n');

% only return active (nonzero) traces
physio.UUID = UUID1;
physio.SliceMap = SliceMap;
physio.ACQ = ACQ;
if (~isempty(ECG) && nnz(ECG(:,1))), physio.ECG1 = ECG(:,1); end
if (~isempty(ECG) && nnz(ECG(:,2))), physio.ECG2 = ECG(:,2); end
if (~isempty(ECG) && nnz(ECG(:,3))), physio.ECG3 = ECG(:,3); end
if (~isempty(ECG) && nnz(ECG(:,4))), physio.ECG4 = ECG(:,4); end
if (~isempty(RESP) && nnz(RESP)), physio.RESP = RESP; end
if (~isempty(PULS) && nnz(PULS)), physio.PULS = PULS; end
if (~isempty(EXT) && nnz(EXT(:,1))), physio.EXT = EXT(:,1); end
if (~isempty(EXT) && nnz(EXT(:,2))), physio.EXT2 = EXT(:,2); end

%--------------------------------------------------------------------------

function [arr, varargout] = readParseFile(fn, LogDataType, ExpectedVersion, FirstTime, ExpectedSamples)
% read and parse log file

fprintf('Reading %s file...\n', LogDataType);

arr = [];

fp = fopen(fn);
while (~feof(fp))
    line = strtrim(fgetl(fp));

    % strip any comments
    if (strfind(line, '#') > 1), line = strtrim(line(1:ctest-1)); end

    if (strfind(line, '='))
        % this is an assigned value; parse it
        varcell = textscan(line, '%s=%s');
        varname = strtrim(varcell{1});
        value   = strtrim(varcell{2});
        
        if (strcmp(varname, 'UUID')), varargout{1} = value; end
        %if (strcmp(varname, 'ScanDate')), ScanDate = value; end
        if (strcmp(varname, 'LogVersion'))
            if (~strcmp(value, ExpectedVersion))
                error('File format [%s] not supported by this function (expected [%s]).', value, ExpectedVersion);
            end
        end
        if (strcmp(varname, 'LogDataType'))
            if (~strcmp(value, LogDataType))
                error('Expected [%s] data, found [%s]? Check filenames?', LogDataType, value);
            end
        end
        if (strcmp(varname, 'SampleTime'))
            if (strcmp(LogDataType, 'ACQUISITION_INFO'))
                error('Invalid [%s] parameter found.',varname);
            end
            SampleTime = uint16(str2double(value));
        end
        if (strcmp(varname, 'NumSlices'))
            if (~strcmp(LogDataType, 'ACQUISITION_INFO'))
                error('Invalid [%s] parameter found.',varname);
            end
            NumSlices = uint16(str2double(value));
            varargout{2} = NumSlices;
        end
        if (strcmp(varname, 'NumVolumes'))
            if (~strcmp(LogDataType, 'ACQUISITION_INFO'))
                error('Invalid [%s] parameter found.',varname);
            end
            NumVolumes = uint16(str2double(value));
            varargout{3} = NumVolumes;
        end
        if (strcmp(varname, 'FirstTime'))
            if (~strcmp(LogDataType, 'ACQUISITION_INFO'))
                error('Invalid [%s] parameter found.',varname);
            end
            FirstTime = uint32(str2double(value));
            varargout{4} = FirstTime;
        end
        if (strcmp(varname, 'LastTime'))
            if (~strcmp(LogDataType, 'ACQUISITION_INFO'))
                error('Invalid [%s] parameter found.',varname);
            end
            varargout{5} = uint32(str2double(value));
        end
        
    elseif (~isempty(line))
        % this must be data; currently it is always 4 columns so we can
        % parse it easily with textscan
        datacells = textscan(line, '%s %s %s %s');

        if (~isstrprop(datacells{1}{1}(1), 'digit'))
            % if the first column isn't numeric, it is probably the header
        else
            % store data in output array based on the file type
            if (strcmp(LogDataType, 'ACQUISITION_INFO'))
                if (isempty(arr)), arr = zeros(2,NumVolumes,NumSlices,'uint32'); end
                curvol    = uint16(str2double(datacells{1}{1})) + 1;
                curslc    = uint16(str2double(datacells{2}{1})) + 1;
                curstart  = uint32(str2double(datacells{3}{1}));
                curfinish = uint32(str2double(datacells{4}{1}));
                if (arr(:,curvol,curslc)), error('Received duplicate timing data for vol%d slc%d!', curvol, curslc); end
                arr(:,curvol,curslc) = [curstart curfinish]; %#ok<AGROW>
            else
                curstart   = uint32(str2double(datacells{1}{1})) - FirstTime + 1;
                curchannel = datacells{2}{1};
                curvalue   = uint16(str2double(datacells{3}{1}));
                %curtrigger = datacells{4}{1};

                if (strcmp(LogDataType, 'ECG'))
                    if (isempty(arr)), arr = zeros(ExpectedSamples,4,'uint16'); end
                    if (strcmp(curchannel, 'ECG1'))
                        chaidx = 1;
                    elseif (strcmp(curchannel, 'ECG2'))
                        chaidx = 2;
                    elseif (strcmp(curchannel, 'ECG3'))
                        chaidx = 3;
                    elseif (strcmp(curchannel, 'ECG4'))
                        chaidx = 4;
                    else
                        error('Invalid ECG channel ID [%s]', curchannel);
                    end
                elseif (strcmp(LogDataType, 'EXT'))
                    if (isempty(arr)), arr = zeros(ExpectedSamples,2,'uint16'); end
                    if (strcmp(curchannel, 'EXT'))
                        chaidx = 1;
                    elseif (strcmp(curchannel, 'EXT2'))
                        chaidx = 2;
                    else
                        error('Invalid EXT channel ID [%s]', curchannel);
                    end
                else
                    if (isempty(arr)), arr = zeros(ExpectedSamples,1,'uint16'); end
                    chaidx = 1;
                end
                
                arr(curstart:curstart+uint32(SampleTime-1),chaidx) = curvalue*ones(SampleTime,1,'uint16'); %#ok<AGROW>
            end
        end
    end
end

if (strcmp(LogDataType, 'ACQUISITION_INFO'))
    arr = arr - FirstTime;
end

%--------------------------------------------------------------------------
