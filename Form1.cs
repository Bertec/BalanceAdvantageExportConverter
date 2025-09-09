using System.Data;

namespace BalanceAdvantageExportConverter
{
	public partial class Form1 : Form
	{
		private Label lblInstructions = null!;
		private Button btnSelectFile = null!;
		private Label lblStatus = null!;

		public Form1()
		{
			InitializeComponent();
			SetupUI();
		}

		private void SetupUI()
		{
			this.Text = "Bertec Export Format Conversion";
			this.Width = 600;
			this.Height = 350;

			lblInstructions = new Label
			{
				Text = "This program reads a new Bertec export file and converts it to the old export format.\n\n" +
						  "1. Select a valid export file\n" +
						  "2. The files will be saved to a subfolder named oldExport under the same folder containing the original file.",
				AutoSize = true,
				Location = new System.Drawing.Point(20, 20)
			};
			this.Controls.Add(lblInstructions);

			btnSelectFile = new Button
			{
				Text = "Select BBA Export File",
				Location = new System.Drawing.Point(20, 120),
				Width = 200
			};
			btnSelectFile.Click += BtnSelectFile_Click;
			this.Controls.Add(btnSelectFile);

			lblStatus = new Label
			{
				Text = "",
				AutoSize = true,
				Location = new System.Drawing.Point(20, 160)
			};
			this.Controls.Add(lblStatus);
		}

		private void BtnSelectFile_Click(object? sender, EventArgs e)
		{
			using var ofd = new OpenFileDialog
			{
				Filter = "CSV files (*.csv)|*.csv|Text files (*.txt)|*.txt",
				Title = "Select BBA Export file"
			};

			if (ofd.ShowDialog() == DialogResult.OK)
			{
				lblStatus.Text = "Please Wait...";
				Application.DoEvents();

				try
				{
					ConvertFile(ofd.FileName);
					lblStatus.Text = $"Finished! The files are saved in:\n{Path.Combine(Path.GetDirectoryName(ofd.FileName) ?? "", "oldExport")}";
				}
				catch (Exception ex)
				{
					lblStatus.Text = $"ERROR - {ex.Message}";
				}
			}
		}

		private void ConvertFile(string datafile)
		{
			string pathname = Path.GetDirectoryName(datafile) ?? "";
			string infilename = Path.GetFileName(datafile);
			string expath = "oldExport";
			string basepath = Path.Combine(pathname, expath);

			var tmp = infilename.Split('-');
			if (tmp.Length < 3)
				throw new Exception("The selected file is not a Bertec export file");

			string basefile = $"{tmp[0]}-{tmp[1]}-";

			// Read all lines
			var lines = File.ReadAllLines(datafile);

			// Find section indices
			int nInfo = -1, nSettings = -1, nResults = -1, nForce = -1;
			for (int i = 0; i < lines.Length; i++)
			{
				switch (lines[i].Trim())
				{
					case "INFO": nInfo = i; break;
					case "SETTINGS": nSettings = i; break;
					case "RESULTS": nResults = i; break;
					case "FORCE": nForce = i; break;
				}
				if (nForce >= 0) break;
			}
			if (nInfo < 0)
				throw new Exception("The selected file is not a Bertec export file");

			int nNext = (nSettings < 0) ? nResults : nSettings;

			// Parse INFO section
			var Infocsv = new string[2, 8];
			Infocsv[0, 6] = "Test Options";
			string Testname = "";
			double height = 0;
			for (int i = nInfo + 1, j = 0; i < nNext - 1; i++, j++)
			{
				var tempstr = lines[i].Split(',');
				string key = tempstr[0].Replace("_", " ");
				string value = tempstr.Length > 1 ? tempstr[1] : "";

				switch (key)
				{
					case "Patient Name": Infocsv[0, 0] = key; Infocsv[1, 0] = value; break;
					case "Patient Age": Infocsv[0, 1] = key; Infocsv[1, 1] = value; break;
					case "DOB": Infocsv[0, 2] = key; Infocsv[1, 2] = value; break;
					case "Patient Gender": Infocsv[0, 3] = "Gender"; Infocsv[1, 3] = value; break;
					case "Operator": Infocsv[0, 4] = key; Infocsv[1, 4] = value; break;
					case "Test Name": Infocsv[0, 5] = key; Infocsv[1, 5] = value; Testname = value; break;
					case "Test Option": Infocsv[0, 6] = key; Infocsv[1, 6] = value; break;
					case "Session Note": Infocsv[0, 7] = "Test Comments"; Infocsv[1, 7] = value; break;
				}
				if (key == "Height")
				{
					var heightstr = value;
					if (heightstr.Contains("'"))
					{
						var hft = double.Parse(heightstr.Split('\'')[0]);
						var hin = double.Parse(heightstr.Split('\'')[1].Replace("\"", ""));
						height = hft * 0.3 + hin * 0.0254;
					}
					else
					{
						height = double.TryParse(heightstr, out var h) ? h : 0;
					}
				}
			}

			// Parse SETTINGS section
			List<string[]> SettingsRows = new();
			if (nSettings >= 0)
			{
				for (int i = nSettings + 1; i < nResults - 1; i++)
				{
					var row = lines[i].Split(',');
					SettingsRows.Add(row);
				}
			}

			// Parse RESULTS section
			List<string[]> ResultsRows = new();
			for (int i = nResults + 1; i < nForce - 1; i++)
			{
				var row = lines[i].Split(',');
				if (i > nResults + 1 && row[0] != "Fall")
				{
					var parsedRow = new List<string> { row[0] };
					for (int k = 1; k < row.Length; k++)
					{
						if (double.TryParse(row[k], out double val))
							parsedRow.Add(val.ToString());
						else
							parsedRow.Add(row[k]);
					}
					ResultsRows.Add(parsedRow.ToArray());
				}
				else
				{
					for (int k = 1; k < row.Length; k++)
					{
						if (string.IsNullOrEmpty(row[k]))
							row[k] = row[k - 1];
					}
					ResultsRows.Add(row);
				}
			}

			// Parse FORCE section
			int headerLines = nForce + 1;
			var forceLines = lines.Skip(headerLines).ToArray();
			DataTable ForceTable = new();
			if (forceLines.Length > 0)
			{
				var headers = forceLines[0].Split(',');
				foreach (var h in headers)
					ForceTable.Columns.Add(h);

				for (int i = 1; i < forceLines.Length; i++)
				{
					var values = forceLines[i].Split(',');
					ForceTable.Rows.Add(values);
				}
			}

			// Create output directory
			Directory.CreateDirectory(basepath);

			// Write Info CSV
			string infofile = Path.Combine(basepath, $"{basefile}1-{Testname}-Info.csv");
			using (var sw = new StreamWriter(infofile))
			{
				for (int i = 0; i < 2; i++)
				{
					for (int k = 0; k < 8; k++)
					{
						sw.Write(Infocsv[i, k]);
						if (k < 7) sw.Write(",");
					}
					sw.WriteLine();
				}
			}

			// Write Settings CSV
			if (SettingsRows.Count > 0)
			{
				string settingsfile = Path.Combine(basepath, $"{basefile}1-{Testname}-Settings.csv");
				using (var sw = new StreamWriter(settingsfile))
				{
					foreach (var row in SettingsRows)
						sw.WriteLine(string.Join(",", row));
				}
			}

			// Write Results CSV
			if (ResultsRows.Count > 0)
			{
				string resultsfile = Path.Combine(basepath, $"{basefile}1-{Testname}-Results.csv");
				using (var sw = new StreamWriter(resultsfile))
				{
					foreach (var row in ResultsRows)
						sw.WriteLine(string.Join(",", row));
				}
			}

			// Write Force CSV
			if (ForceTable.Rows.Count > 0)
			{
				string forcefile = Path.Combine(basepath, $"{basefile}1-{Testname}-Force.csv");
				using (var sw = new StreamWriter(forcefile))
				{
					// Write headers
					sw.WriteLine(string.Join(",", ForceTable.Columns.Cast<DataColumn>().Select(c => c.ColumnName)));
					// Write rows
					foreach (DataRow row in ForceTable.Rows)
						sw.WriteLine(string.Join(",", row.ItemArray.Select(x => x?.ToString() ?? string.Empty)));
				}
			}
		}
	}
}
