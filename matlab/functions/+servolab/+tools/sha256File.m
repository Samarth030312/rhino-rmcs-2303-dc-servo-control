function h = sha256File(file)
%SHA256FILE  SHA-256 of a file as lower-case hex, on any OS.
%
%   h = servolab.tools.sha256File(file)
%
%   Uses Java's MessageDigest when MATLAB has a JVM, otherwise the OS tool
%   (certutil on Windows, shasum on macOS, sha256sum on Linux).
    assert(isfile(file), 'servolab:tools:sha256', 'no such file: %s', file);
    if usejava('jvm')
        md = java.security.MessageDigest.getInstance('SHA-256');
        fid = fopen(file, 'r'); c = onCleanup(@() fclose(fid));
        while true
            b = fread(fid, 2^20, '*int8');
            if isempty(b), break; end
            md.update(b);
        end
        d = typecast(md.digest(), 'uint8');
        h = lower(reshape(dec2hex(d, 2)', 1, []));
        return
    end
    if ispc
        [st, out] = system(sprintf('certutil -hashfile "%s" SHA256', file));
        tok = regexp(out, '([0-9a-fA-F ]{64,95})', 'tokens', 'once');
        if st ~= 0 || isempty(tok), error('servolab:tools:sha256', 'certutil failed: %s', out); end
        h = lower(strrep(tok{1}, ' ', ''));
    else
        tool = 'sha256sum'; if ismac, tool = 'shasum -a 256'; end
        [st, out] = system(sprintf('%s "%s"', tool, file));
        if st ~= 0, error('servolab:tools:sha256', '%s failed: %s', tool, out); end
        h = lower(strtok(out));
    end
end
