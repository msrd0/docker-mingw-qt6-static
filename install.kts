import java.io.File
import kotlin.system.exitProcess

fun eprintln(msg: String) = System.err.println(msg)

fun die(msg: String): Nothing {
	eprintln(msg)
	exitProcess(1)
}

fun buildProcess(cmd: Array<out String>, dir: File?): ProcessBuilder {
	val proc = ProcessBuilder(*cmd)
	dir?.let { proc.directory(dir) }
	return proc
}

fun run(vararg cmd: String, dir: File? = null) {
	val proc = buildProcess(cmd, dir)
		.redirectOutput(ProcessBuilder.Redirect.INHERIT)
		.redirectError(ProcessBuilder.Redirect.INHERIT)
		.start()
	val exitCode = proc.waitFor()
	if (exitCode != 0) {
		die("Process ${cmd[0]} returned non-zero exit code $exitCode")
	}
}

fun test(vararg cmd: String, dir: File? = null): String? {
	val proc = buildProcess(cmd, dir)
		.redirectOutput(ProcessBuilder.Redirect.PIPE)
		.redirectError(ProcessBuilder.Redirect.PIPE)
		.start()
	val exitCode = proc.waitFor()
	if (exitCode != 0) {
		return null
	}
	return proc.inputStream.bufferedReader().readText()
}

fun install(pkg: String) {
	println("")
	println("[$pkg] Preparing to build package ...")
	
	val dir = File(pkg)
	if (dir.exists()) {
		println("[$pkg] Updating AUR repository ...")
		run("git", "pull", dir=dir)
	} else {
		println("[$pkg] Cloning AUR repository ...")
		run("git", "clone", "--depth", "1", "https://aur.archlinux.org/$pkg")
	}

	// inspect the srcinfo file
	val srcinfo = File(dir, ".SRCINFO")
	val deps = mutableListOf<String>()
	val keys = mutableListOf<String>()
	for (line in srcinfo.readLines()) {
		val parts = line.trim().split(Regex("\\s+"))
		if (parts.size != 3 || parts[1] != "=") {
			continue
		}
		
		// TODO better handling of split packages
		if (parts[0] == "pkgname") {
			break
		}
		
		if (parts[0] == "depends" || parts[0] == "makedepends") {
			deps.add(parts[2])
		} else if (parts[0] == "validpgpkeys") {
			keys.add(parts[2])
		}
	}
	deps.sort()
	println("[$pkg] Dependencies: " + deps.joinToString())

	if (keys.isNotEmpty()) {
		run("gpg", "--recv-keys", *keys.toTypedArray())
	}

	val installRepo = mutableListOf<String>()
	val installAur = mutableListOf<String>()
	deps.forEach dep@ { dep ->
		// check if package is installed already
		if (test("pacman", "-Qi", dep) != null) {
			return@dep
		}
		
		// check if package is available from the repositories
		if (test("pacman", "-Si", dep) != null) {
			installRepo.add(dep)
			return@dep
		}
		
		// otherwise, we'll need to install it from the AUR
		installAur.add(dep)
	}
	
	if (installRepo.isNotEmpty()) {
		run("sudo", "pacman", "-Sy", "--noconfirm", *installRepo.toTypedArray())
	}
	
	installAur.forEach { dep ->
		install(dep)
	}
	
	println("[$pkg] Invoking makepkg ...")
	run("makepkg", dir=dir)
	
	println("[$pkg] Installing package ...")
	run("bash", "-euc", "yes | sudo pacman -U $pkg-*.pkg.tar", dir=dir)
	
	println("[$pkg] Done")
	if (!dir.deleteRecursively()) {
		println("[$pkg] WARN failed to clean up")
	}
}

val pkg = System.getenv("PKG") ?: die("Missing PKG environment variable")
install(pkg)

// clean up the repository
// do not set pipefail - it will trigger since yes never closes its output
run("bash", "-euc", "yes | sudo pacman -Scc")
