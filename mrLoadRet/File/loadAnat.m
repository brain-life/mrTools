function [view anatFilePath] = loadAnat(view,anatFileName,anatFilePath)
%
% view = loadAnat(view,[anatFileName],[anatFilePath])
%
% Loads an anatomy array and sets view.baseVolumes to include.
%
% anatFileName: Anatomy file. If not specified or empty, prompts user to
% select the file. Anatomy file must be nifti format. anatFileName must be
% in the <homedir>/Anatomy subdirectory. Use symbolic links to point to a
% shared directory for volume anatomy files.
%
% anatFilePath is the path of where to open up the dialog. This
% will bey returned so that the GUI can open up in the same
% place each time.
%
% djh, 1/9/98
% 5/2005, djh, update to mrLoadRet-4.0

%%%%%%%%%%%%%%%%%%%%%%%%%
% Load the anatomy file %
%%%%%%%%%%%%%%%%%%%%%%%%%

if ieNotDefined('anatFilePath')
    anatFilePath = ''; 
end

% Open dialog box to have user choose the file
if ieNotDefined('anatFileName')
    if ieNotDefined('anatFilePath')
        startPathStr = viewGet(view,'anatomyDir');
    else
        startPathStr = anatFilePath;
    end
    filterspec = {'*.img;*.nii','Nifti/Analyze files'};
    title = 'Choose anatomy file';
    pathStr = getPathStrDialog(startPathStr,title,filterspec);
elseif ieNotDefined('anatFilePath')
    pathStr = fullfile(viewGet(view,'anatomyDir'),anatFileName);
else
    pathStr = fullfile(anatFilePath,anatFileName);
end

% Aborted
if ieNotDefined('pathStr')
    return
end

% Strip extension to make sure it is .mat
pathStr = [stripext(pathStr),'.img'];

% File does not exist
if ~exist(pathStr,'file')
    mrWarnDlg(['File ',pathStr,' not found']);
    return
end

[path,name,ext,versn] = fileparts(pathStr);
anatFilePath = path;

% Load nifti file and reorder the axes and flip (site specific).
h = mrMsgBox(['Loading volume: ',pathStr,'. Please wait']);
hdr = cbiReadNiftiHeader(pathStr);

% get volume dimension...
% hdr.dim(1) should probably be the number of dimensions
% but some files don't seem to have this set properly
% so this check seems to work
volumeDimension = sum((hdr.dim(2:end)~=1)&(hdr.dim(2:end)~=0));

% Error if it dimension is greater than 4D.
if (volumeDimension > 4)
    mrErrorDlg(['Volume must be 3D or 4D. This file contains a ',num2str(volumeDimension),'D array.']);
end

% Handle 4D file
if (volumeDimension == 4)
    paramsInfo = {{'frameNum',0,'incdec=[-1 1]',sprintf('minmax=[0 %i]',hdr.dim(5)),'This volume is a 4D file, to display it as an anatomy you need to choose a particular time point or take the mean over all time points. Setting this value to 0 will compute the mean, otherwise you can select a particular timepoint to display'}};
    params = mrParamsDialog(paramsInfo,'Choose which frame of 4D file. 0 for mean');
    if isempty(params)
        return
    end
    % if frameNum is set to 0, take the mean
    if params.frameNum == 0
      [vol hdr] = cbiReadNifti(pathStr);
      vol = nanmean(vol,4);
    % other wise single time slice
    else
      [vol hdr] = cbiReadNifti(pathStr,{[] [] [] params.frameNum});
    end
else
  % if 3D file just load
  [vol hdr] = cbiReadNifti(pathStr);
end

% Warning if no alignment information in the header.
if ~hdr.sform_code
    mrWarnDlg('No base coordinate frame in the volume header.');
end

% Extract permutation matrix to keep track of slice orientation.
% This logic which is admittedly arcane is duplicated in mrAlignGUI. If you
% make changes here, please update that function as well.
[q,r] = qr(inv(hdr.qform44(1:3,1:3)));
permutationMatrix = abs([q(1,:); q(2,:); q(3,:)]);

%%%%%%%%%%%%%%%%%%%%%%
% Add it to the view %
%%%%%%%%%%%%%%%%%%%%%%

% Set structure fields
base.name = name;
base.data = vol;
base.hdr = hdr;
base.permutationMatrix = permutationMatrix;
base.range = [min(vol(:)) max(vol(:))];
base.clip = defaultClip(vol);

% Add it to the list of base volumes and select it
view = viewSet(view,'newBase',base);



function clip = defaultClip(image)
% Choose default clipping based on histogram
histThresh = length(image(:))/1000;
[cnt, val] = hist(image(:),100);
goodVals = find(cnt>histThresh);
clipMin = val(min(goodVals));
clipMax = val(max(goodVals));
clip = [clipMin,clipMax];
