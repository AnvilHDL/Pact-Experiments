import sys
import os


CUR_DIR = os.path.dirname(os.path.abspath(__file__))


def get_all_files_in_dir(directory):
    if not os.path.exists(directory):
        print(f"Error: Directory {directory} does not exist.")
        sys.exit(1)
        
    all_files = []
    for root, _, files in os.walk(directory):
        for file in files:
            if file.endswith(('.sv', '.svh')):
                all_files.append(os.path.abspath(os.path.join(root, file)))
    return all_files


def get_testbench_dependencies(RTL_DIR, flist):
    if not os.path.exists(RTL_DIR):
        print(f"Error: RTL directory {RTL_DIR} does not exist.")
        sys.exit(1)

    flist_path = os.path.join(RTL_DIR, flist)
    if not os.path.exists(flist_path):
        print(f"Error: File list {flist_path} does not exist.")
        sys.exit(1)
        
    with open(flist_path, 'r') as file:
        dependencies_list = file.readlines()
        
        inc_dirs = [line.split("+incdir+")[1].strip() for line in dependencies_list if line.startswith("+incdir+")]
        print(f"Found {len(inc_dirs)} include directories: {inc_dirs}")

        for dir in inc_dirs:
            all_files = get_all_files_in_dir(dir)
            dependencies_list.extend(all_files)

        if (not 'aes' in flist):
            dependencies_list += [f for f in get_all_files_in_dir(RTL_DIR) if '_lite_' in f ]
            cleaned_dependencies = [dep.strip() for dep in dependencies_list if dep.strip() and not dep.startswith("+incdir+")]
            cleaned_dependencies = list(set(cleaned_dependencies))
            for f in cleaned_dependencies:
                if 'test' in os.path.basename(f):
                    print(f"Removing testbench file: {f}")
                    cleaned_dependencies.remove(f)
            return cleaned_dependencies
        else:
            #remove newline characters and spaces from the dependencies_list
            dependencies_list = [dep.strip() for dep in dependencies_list if dep.strip()]
            remove_duplicates_with_order = []
            for dep in dependencies_list:
                if dep not in remove_duplicates_with_order:
                    remove_duplicates_with_order.append(dep)

            return remove_duplicates_with_order


def preprocess_files(file):
    if not os.path.exists(file):
        print(f"Error: File {file} does not exist.")
        sys.exit(1)
    with open(file, 'r') as f:
        content = f.read()
        content = content.replace('`include', '// `include')
        return content

def create_synthesis_harness(dependencies_list,testbench_name):
    if not 'aes' in testbench_name:
        dependencies_list.sort(key=lambda x: (not ((x.endswith('.svh')) or ('pkg' in os.path.basename(x))), x))
    # if 'aes' in testbench_name:
    #     ent = [f for f in dependencies_list if 'entropy_src_pkg.sv' in f]
    #     prim = [f for f in dependencies_list if 'prim_util_pkg.sv' in f]
    #     aes_reg = [f for f in dependencies_list if 'aes_reg_pkg.sv' in f]
    #     prim_assert_dummy = [f for f in dependencies_list if 'prim_assert_dummy_macros.svh' in f]
    #     prim_assert = [f for f in dependencies_list if 'prim_assert.sv' in f]
    #     aes_main_files = [f for f in dependencies_list if 'aes.sv' in f or 'aes_wrap.sv' in f or 'aes_control.sv' in f or 'aes_core.sv' in f or 'aes.sv' in f or 'aes_control_fsm.sv' in f or 'aes_control_fsm_p.sv' in f or 'aes_control_fsm_n.sv' in f]
    #     dependencies_list = [f for f in dependencies_list if f not in aes_main_files]

    #     if prim_assert_dummy:
    #         dependencies_list.remove(prim_assert_dummy[0])
    #         dependencies_list.insert(0, prim_assert_dummy[0])
    #     if prim_assert:
    #         dependencies_list.remove(prim_assert[0])
    #         dependencies_list.insert(1, prim_assert[0])
    #     if prim:
    #         dependencies_list.remove(prim[0])
    #         dependencies_list.insert(2, prim[0])
    #     if ent:
    #         dependencies_list.remove(ent[0])
    #         dependencies_list.insert(3, ent[0])
    #     if aes_reg:
    #         dependencies_list.remove(aes_reg[0])
    #         dependencies_list.insert(4, aes_reg[0])
        
        

    
    # print(f"sorted dependencies list: {dependencies_list}")
    SRC_DIR = os.path.join(CUR_DIR, "../build")
    os.makedirs(SRC_DIR, exist_ok=True)
    SYNTH_DIR = os.path.join(SRC_DIR, testbench_name.split('.')[0])
    if os.path.exists(SYNTH_DIR):
        print(f"Warning: Directory {SYNTH_DIR} already exists. It will be overwritten.")
        os.system(f"rm -rf {SYNTH_DIR}")
    os.makedirs(SYNTH_DIR, exist_ok=True)
    os.makedirs(os.path.join(SYNTH_DIR, "rtl"), exist_ok=True)
    print(f"Synthesis directory created at: {SYNTH_DIR}")
    for dep in dependencies_list:
        content = preprocess_files(dep)
        with open(os.path.join(SYNTH_DIR, "rtl", testbench_name), 'a') as f:
            f.write(f"//=========================File: {os.path.basename(dep)}================\n")
            f.write(content)
    #     with open(f"{SYNTH_DIR}/rtl/{os.path.basename(dep)}", 'w') as f:
    #         f.write(content)
    # os.system(f"zip -r synthesis_harness.zip synthesis")
    # os.system(f"rm -rf {SYNTH_DIR}")

def main():
    if len(sys.argv) < 4:
        print("Usage: python create_synthesis_harness.py <testbench_path> <file_list> testbench_name")
        sys.exit(1)

    testbench_path = sys.argv[1]
    rtl_path = os.path.abspath(testbench_path)
    flist = sys.argv[2]
    testbench_name = sys.argv[3]+ ".sv"

    dependencies_list = get_testbench_dependencies(rtl_path, flist)

    print(f"Found {len(dependencies_list)} dependencies for the testbench.")


    if not dependencies_list:
        print("No dependencies found for the testbench.")
        sys.exit(1)


    create_synthesis_harness(dependencies_list, testbench_name)
    print("Synthesis harness created successfully.")


if __name__ == "__main__":
    main()


    

