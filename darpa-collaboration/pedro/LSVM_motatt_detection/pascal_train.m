function model = pascal_train(cls, n, note, year)

% no flipping in the model
% model = pascal_train(cls, n, note)
% Train a model with 2*n components using the PASCAL dataset.
% note allows you to save a note with the trained model
% example: note = 'testing FRHOG (FRobnicated HOG)

% At every "checkpoint" in the training process we reset the 
% RNG's seed to a fixed value so that experimental results are 
% reproducible.
initrand();

if nargin < 3
  note = '';
end

setVOCyear = year;
globals; 
[pos, neg] = pascal_data(cls, true, VOCyear);
%neg=neg(1:100);
% split data by aspect ratio into n groups
spos = split(cls, pos, n);

cachesize = 24000;
maxneg = 200;
cachedir_note = fullfile(cachedir, note);
if ~exist(cachedir_note, 'dir')
    mkdir(cachedir_note);
end;

% train root filters using warped positives & random negatives
try
  load(fullfile(cachedir_note, [cls '_lrsplit1.mat']));
catch
  initrand();
  for i = 1:n
    % split data into two groups: left vs. right facing instances
    models{i} = initmodel(cls, spos{i}, note, 'N');
    inds = lrsplit(models{i}, spos{i}, i);
    models{i} = train(cls, note, models{i}, spos{i}(inds), neg, i, 1, 1, 1, ...
                      cachesize, true, 0.7, false, ['lrsplit1_' num2str(i)]);
  end
  save(fullfile(cachedir_note, [cls '_lrsplit1.mat']), 'models');
end

% train root left vs. right facing root filters using latent detections
% and hard negatives
try
  load(fullfile(cachedir_note, [cls '_lrsplit2.mat']));
catch
  initrand();
  for i = 1:n
    models{i} = lrmodel(models{i});
    models{i} = train(cls, note, models{i}, spos{i}, neg(1:maxneg), 0, 0, 4, 3, ...
                      cachesize, true, 0.7, false, ['lrsplit2_' num2str(i)]);
  end
  save(fullfile(cachedir_note, [cls '_lrsplit2.mat']), 'models');
end

% merge models and train using latent detections & hard negatives
try 
  load(fullfile(cachedir_note, [cls '_mix.mat']));
catch
  initrand();
  model = mergemodels(models);
  model = train(cls, note, model, pos, neg(1:maxneg), 0, 0, 1, 5, ...
                cachesize, true, 0.7, false, 'mix');
  save(fullfile(cachedir_note, [cls '_mix.mat']), 'model');
end

% add parts and update models using latent detections & hard negatives.
try 
  load(fullfile(cachedir_note, [cls '_parts.mat']));
catch
  initrand();
  for i = 1:2:2*n
    model = model_addparts(model, model.start, i, i, 8, [6 6]);
  end
  model = train(cls, note, model, pos, neg(1:maxneg), 0, 0, 8, 10, ...
                cachesize, true, 0.7, false, 'parts_1');
  model = train(cls, note, model, pos, neg, 0, 0, 1, 5, ...
                cachesize, true, 0.7, true, 'parts_2');
  save(fullfile(cachedir_note, [cls '_parts.mat']), 'model');
end

save(fullfile(cachedir_note, [cls '_final.mat']), 'model');
