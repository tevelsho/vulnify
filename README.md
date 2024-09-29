<div align="center">
  <h1>Vulnify</h1>
  <br/>

  <p><i>Vulnify is a PowerShell tool that automatically identifies and tests vulnerable Windows kernel drivers from the <a href="https://www.loldrivers.io/api/drivers.json">LOTL API list</a> created by <a href="https://www.linkedin.com/in/tevelsho">@TevelSho</a>.</i></p>
  <br />

  <img src="assets/vulnify_results.jpg" width="70%" /><br />
</div>

> :warning: Vulnify is just a quick PoC. Breaking changes may be made to APIs and also there are many known bugs and issues.

### Quick Start

Vulnify source code available <a href="https://github.com/tevelsho/dso-automated-penetration-testing-v1/tree/Main/scripts">here</a> and can be cloned using `git clone`:
```bash
git clone https://github.com/tevelsho/dso-automated-penetration-testing-v1.git
```

After cloing the project we are going to need to change the current directory to the cloned repository:
```bash
cd dso-automated-penetration-testing-v1
```

#### Install the dependencies
After following the steps above we need to install the needed dependecies for the script to run. 

> Ensure that <a href="https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.4">PowerShell 7 or higher</a> is installed.

> Ensure that <a href="https://code.visualstudio.com/docs/languages/powershell">VS Code PowerShell extension</a> is installed.

#### Running Vulnify
Due to Version and Admin Privilege issues in Powershell, the tool had to be split up into two scripts (`Filter` & `Loader`).

Navigate to the directory where the PowerShell scripts are located at:
```bash
cd scripts
```

Allow script execution in PowerShell:
```powershell
Set-ExecutionPolicy RemoteSigned
```

Run Vulnify:
```
./vulnify.ps1

    _    ____  ____    _   ______________  __
    | |  / / / / / /   / | / /  _/ ____/\ \/ /
    | | / / / / / /   /  |/ // // /_     \  /
    | |/ / /_/ / /___/ /|  // // __/     / /
    |___/\____/_____/_/ |_/___/_/       /_/

    one driver at a time

Vulnify [Version: 1.0.0]

Usage:
    ./vulnify.ps1 [flags]

Flags:

    -dd <date>      filter by full creation date (yy-mm-dd)
    -u  <usecase>   filter by exploit use case
    -h              help for Vulnify

Examples:

    ./vulnify.ps1 -a
    ./vulnify.ps1 -dd "2023-05-06" -u "Elevate privileges"
```

<i>Note: `vulnify.ps1` automatically calls `loader.ps1` once it has finish running. If the script breaks halfway, either re-run the script OR run the loader with the folder (full path) containing the vulnerable drivers:</i>
```powershell
.\loader.ps1 -f "~\dso-automated-penetration-testing-v1\vulnerable_LOTL_drivers"
```

Vulnify works well on the latest Window's Machines (23H2). It's recommended to use the latest versions possible to avoid issues.

If you run into issues, check the [Known Issues](#known-issues).

---

### Features

> Driver Filtering

- Creation Date
- Use Case

---

### Known Issues


### Potential Features

- Filter by year only.
- Saving vulnreable driver's MD5 hashes to a file.
- Stopping & removing vulnreable drivers from the system after testing.

### Contributing

To contribute to Vulnify, please open a pull-request! 

### Note

Please do not open any issues regarding those in [Known Issues](#known-issues). 


