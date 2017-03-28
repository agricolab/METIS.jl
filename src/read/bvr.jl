module BVR

function readEEG(DataInfo::Dict,ChanInfo)
    Filename = get(DataInfo,"eegFile","")
    open(Filename) do f
        FileSize    = position(seekend(f))
        FrameNumber = Int64(FileSize/( get(DataInfo,"ByteLength",2) * get(DataInfo,"ChannelNumber",32)))
        FileDim     = (get(DataInfo,"ChannelNumber",32),FrameNumber)
        seekstart(f)
        trial       = float(read(f, Int16, FileDim[1],FileDim[2]))
    end
    trial       = trial.*repmat(ChanInfo[2,:],1,size(trial,2))
    return trial
end

function readMRK(DataInfo::Dict)
    doCollect   = false
    MarkerInfo  = hcat(Array{String}(0,1),Array{Int64}(0,1))
    open(get(DataInfo,"vmrkFile","")) do f
        while !eof(f)
            x = readline(f)
            # Read Channel-Specific Info
            if contains(x[1:2],"\r\n"); doCollect = false; end
            if doCollect
                MarkerInfo  = vcat(MarkerInfo,getMarkerSegment(x))
            end
            if contains(x,"; Commas in type or description text are coded")
                doCollect = true
            end
        end
    end
    return MarkerInfo
end

function getMarkerSegment(x)
    k1          = search(x,',')
    k2          = search(x,',',k1+1)
    k3          = search(x,',',k2+1)
    MarkerCode  = x[k1+1:k2-1]
    MarkerSeg   = parse(Int64,x[k2+1:k3-1])
    return hcat(MarkerCode,MarkerSeg)
end

function readHDR(FilePath::String,Filename::String)
    vhdrFilename  = string(FilePath,Filename);
    vmrkFilename  = Nullable{String}()
    eegFilename   = Nullable{String}()
    Fs            = Nullable{Int32}()
    dataFormat    = Nullable{String}()
    bitFormat     = Nullable{Int32}()
    dataOrient    = Nullable{String}()
    binaryFormat  = Nullable{String}()
    NumChan       = Nullable{Int32}()
    ChanInfo      = []
    DataInfo      = []
    doCollect     = false;
    open(vhdrFilename) do f
        while !eof(f)
            x = readline(f)

          # Read General Info
            if contains(x,"MarkerFile=");
                vmrkFilename = string(FilePath,x[search(x,'=')+1:end-2])
            end
            if contains(x,"DataFile=");
                eegFilename = string(FilePath,x[search(x,'=')+1:end-2])
            end
            if contains(x,"Sampling Rate [Hz]:");
                Fs = parse(Int32,getGeneralInfo(x));
            end
            if contains(x,"Number of channels:");
                NumChan = parse(Int32,getGeneralInfo(x));
            end
            if contains(x,"DataFormat")
                dataFormat = getDataInfo(x);
            end
            if contains(x,"DataOrientation")
                dataOrient = getDataInfo(x);
            end
            if contains(x,"BinaryFormat");
                binaryFormat,bitFormat = getEncoding(x)
            end

            # Read Channel-Specific Info
            if contains(x[1:2],"\r\n"); doCollect = false; end
            if doCollect; ChanInfo = hcat(ChanInfo,getChanInfo(x)); end
            if contains(x,"Ch1="); doCollect = true; ChanInfo = getChanInfo(x); end

        end
    end
    DataInfo = (Dict("vhdrFile"=>vhdrFilename,"vmrkFile"=>vmrkFilename,"eegFile"=>eegFilename,"ChannelNumber"=>NumChan,"Encoding"=>binaryFormat,"ByteLength"=>bitFormat,"Format"=>dataFormat,"Orientation"=>dataOrient))
    return Fs, DataInfo, ChanInfo
end

function getChanInfo(x::String)
    s1         = search(x,'h');
    s2         = search(x,'=');
    s3         = search(x,',');
    s4         = search(x,'V');
    name      = x[s2+1:s3-1];
    id        = parse(Int64,x[s1+1:s2-1]);
    res       = parse(Float32,x[s3+2:s4-4]);
    return [name;res;id]
end

function getGeneralInfo(x::String)
    s  = search(x,':');
    return x[s+2:end-2];
end

function getDataInfo(x::String)
    s  = search(x,'=');
    return x[s+1:end-2];
end

function getEncoding(x::String)
    TypeEncode   = Dict("INT_16" => "Int16","UINT_16" => "UInt16","FLOAT_32" => "Float32");
    BitEncode    = Dict("INT_16" => 2,"UINT_16" => 2,"FLOAT_32" => 4);
    return TypeEncode[getDataInfo(x)], BitEncode[getDataInfo(x)];
end
end

function readBVR(FilePath::String,Filename::String)

    Fs, DataInfo, ChanInfo      = BVR.readHDR(FilePath,Filename)
    trial                       = BVR.readEEG(DataInfo,ChanInfo)
    Markers                     = BVR.readMRK(DataInfo)
    EEG                         = Kronos(trial,ChanInfo[1,:],Markers,Fs,DataInfo);
    # TODO Fix issue with lost path for vmrkFile and eegFile #filepath
    return EEG
end


function readBVR(FullFilename::String)
    Fileparts                   = split(FullFilename,'/')
    Filename                    = convert(String,Fileparts[end])
    s                           = search(FullFilename,Fileparts[end])
    FilePath                    = FullFilename[1:s[1]-1]
    Fs, DataInfo, ChanInfo      = BVR.readHDR(FilePath,Filename)
    trial                       = BVR.readEEG(DataInfo,ChanInfo)
    Markers                     = BVR.readMRK(DataInfo)
    EEG                         = Kronos(trial,ChanInfo[1,:],Markers,Fs,DataInfo);
    # TODO Fix issue with lost path for vmrkFile and eegFile #filepath
    return EEG
end
